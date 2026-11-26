"""Regression tests for production world ID and upload connection failures."""
import json
import unittest
from pathlib import Path
from tempfile import TemporaryDirectory
from http.client import RemoteDisconnected
from unittest.mock import patch
from zipfile import ZipFile

from puzzlequest_studio.builder import BuildConfig
from puzzlequest_studio.laravel_import import repair_laravel_world, verify_laravel_archive
from puzzlequest_studio.remote import StudioApiClient,StudioApiError

TOKEN='a'*64

class ProductionWorldPreflight(unittest.TestCase):
    def setUp(self):
        self.client=StudioApiClient('https://puzzlequest.50sols.com', TOKEN)
        self.temp=TemporaryDirectory()
        self.path=Path(self.temp.name)/'test.zip'
        with ZipFile(self.path,'w') as z:
            z.writestr('level.json',json.dumps({'level_id':'level_006_green_valley','world_id':'green-valley','display_code':'1-6',
                           'position':6,'title':{'ar':'طاحونة','en':'Watermill'}, 'piece_count':100}))
    def tearDown(self):self.temp.cleanup()
    def test_default_builder_world_matches_real_seed(self):
        self.assertEqual(BuildConfig.__dataclass_fields__['world_id'].default, 'green_valley')
    def test_world_typo_blocked_before_upload(self):
        with patch.object(self.client,'worlds',return_value=[{'id':'green_valley'}]), \
             patch.object(self.client,'levels',return_value=[]):
            with self.assertRaisesRegex(StudioApiError,'green_valley') as context:
                self.client.preflight_import(self.path)
        self.assertIn("'green-valley'",str(context.exception))
    def test_preflight_accepts_real_world(self):
        with ZipFile(self.path,'w') as z:
            z.writestr('level.json',json.dumps({'level_id':'level_006_green_valley','world_id':'green_valley',
                   'display_code':'1-6','title':{'ar':'طاحونة','en':'Watermill'}}))
        with patch.object(self.client,'worlds',return_value=[{'id':'green_valley'}]), \
             patch.object(self.client,'levels',return_value=[]):
            self.assertEqual(self.client.preflight_import(self.path)['world_id'],'green_valley')
    def test_display_code_duplicate_blocks_upload(self):
        with ZipFile(self.path,'w') as z:
            z.writestr('level.json',json.dumps({'level_id':'level_006_green_valley','world_id':'green_valley',
                   'display_code':'1-6','title':{'ar':'طاحونة','en':'Watermill'}}))
        with patch.object(self.client,'worlds',return_value=[{'id':'green_valley'}]), \
             patch.object(self.client,'levels',return_value=[{'id':'different_level','world_id':'green_valley','display_code':'1-6'}]):
            with self.assertRaisesRegex(StudioApiError,'already used'):
                self.client.preflight_import(self.path)
    def test_remote_disconnect_explains_uncertain_upload_outcome(self):
        with patch.object(self.client,'preflight_import',return_value={}), \
             patch.object(self.client._opener,'open',side_effect=RemoteDisconnected('Remote end closed connection without response')):
            with self.assertRaisesRegex(StudioApiError,'Refresh Revisions'):
                self.client.import_zip(self.path)
    def test_repair_refuses_unsupported_zip(self):
        with self.assertRaises(ValueError):
            repair_laravel_world(self.path,'green_valley')
    def test_repair_rejects_overwriting_input(self):
        with self.assertRaises(ValueError):
            repair_laravel_world(self.path,'green_valley',self.path)

if __name__=='__main__':unittest.main()
