"""No-network security and API contract smoke tests for remote desktop manager."""
import json
import unittest
from urllib.error import HTTPError
from unittest.mock import patch
from puzzlequest_studio.remote import StudioApiClient, StudioApiError

TOKEN='a'*64

class DummyResponse:
    def __init__(self,body=b'{"ok":true}'):
        self.body=body
    def read(self,n):return self.body[:n]
    def __enter__(self):return self
    def __exit__(self,*args):return False

class RemoteStudioContractTests(unittest.TestCase):
    def test_only_clean_https_origins_are_accepted(self):
        for value in ['http://localhost','https://host.example/path','https://u:p@host.example','https://host.example?q=x','javascript:alert(1)']:
            with self.subTest(value=value),self.assertRaises(StudioApiError):StudioApiClient(value,TOKEN)
        self.assertEqual(StudioApiClient('https://example.org',TOKEN).origin,'https://example.org')
    def test_token_is_validated_before_requests(self):
        for token in ['short','AA'*32,'z'*64,'a'*63]:
            with self.assertRaises(StudioApiError):StudioApiClient('https://example.org',token)
    def test_request_path_cannot_escape_or_override_host(self):
        client=StudioApiClient('https://example.org',TOKEN)
        for path in ['/../admin','//bad/path','/levels?admin=1','https://evil.org']:
            with self.assertRaises(StudioApiError):client.get(path)
    def test_api_calls_use_authorization_and_expected_paths(self):
        client=StudioApiClient('https://example.org',TOKEN)
        captured=[]
        def fake_open(req,timeout):
            captured.append((req.full_url,req.get_method(),req.get_header('Authorization')))
            return DummyResponse()
        with patch.object(client._opener,'open',side_effect=fake_open):
            assert client.get('/schema')=={'ok':True}
            assert client.post('/worlds',{'id':'demo'})=={'ok':True}
        assert captured==[
            ('https://example.org/api/studio/v1/schema','GET','Bearer '+TOKEN),
            ('https://example.org/api/studio/v1/worlds','POST','Bearer '+TOKEN)]
    def test_no_secrets_written_and_error_is_reported(self):
        client=StudioApiClient('https://example.org',TOKEN)
        err=HTTPError('https://example.org',401,'Unauthorized',{},None)
        err.read=lambda n:b'{"error":"studio_token_invalid_or_expired"}'
        with patch.object(client._opener,'open',side_effect=err):
            with self.assertRaisesRegex(StudioApiError,'HTTP 401'):client.schema()

if __name__=='__main__':unittest.main()
