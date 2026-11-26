"""Contract tests based on owner-supplied app/Services/Content.php."""
from __future__ import annotations
from dataclasses import replace
from io import BytesIO
from pathlib import Path
from uuid import UUID
import json
import zipfile
import pytest
from PIL import Image
from puzzlequest_studio.builder import BuildConfig
from puzzlequest_studio.laravel_import import build_laravel_package,verify_laravel_archive,REQUIRED_META


@pytest.fixture(scope='module')
def art(tmp_path_factory):
    out=tmp_path_factory.mktemp('art')/'scene.png'
    im=Image.new('RGB',(1024,1024))
    px=im.load()
    for y in range(1024):
        for x in range(1024):px[x,y]=((x*3+y*5)%256,(x*7+y//2)%256,(y*13+x//5)%256)
    im.save(out)
    return out


@pytest.fixture(scope='module')
def sample(art,tmp_path_factory):
    cfg=BuildConfig(image_path=art,output_dir=tmp_path_factory.mktemp('laravel-zip'),
                    piece_count=16,world_id='green_valley',level_id='1-6',
                    title='Watermill',resolution=960,total_seconds=600,
                    three_star_seconds=210,two_star_seconds=420,approved_rights=True)
    return build_laravel_package(cfg,title_ar='طاحونة',title_en='Watermill')


def tamper(src: Path, dest: Path, *, transform=lambda name,data:data, drop=()):
    with zipfile.ZipFile(src) as zin,zipfile.ZipFile(dest,'w',compression=zipfile.ZIP_DEFLATED) as zout:
        for name in zin.namelist():
            if name in drop:continue
            zout.writestr(name,transform(name,zin.read(name)))
    return dest


def test_required_nine_fields_are_direct_level_json_keys(sample):
    with zipfile.ZipFile(sample) as z:
        meta=json.loads(z.read('level.json'));v=json.loads(z.read('manifest.json'))
        assert all(name in meta for name in REQUIRED_META)
        assert 'metadata' not in meta # authoritative Content.php reads $meta from root
        assert meta['display_code']=='1-6'
        assert meta['level_id']=='level_006_green_valley'
        assert meta['title']=={'ar':'طاحونة','en':'Watermill'}
        assert v['schema_version']=='1.0.0' and v['board_size_px']==[960,960]
        assert 'revision_uuid' in meta and UUID(meta['revision_uuid']).version==4
        assert meta['revision_uuid']==v['revision_uuid']
        assert len(v['pieces'])==meta['piece_count']
        assert v['master_image_path']=='master.png'
    assert verify_laravel_archive(sample).passed


@pytest.mark.parametrize('pieces', [16,36,64,100])
def test_server_geometry_for_all_piece_counts(art,tmp_path,pieces):
    cfg=BuildConfig(image_path=art,output_dir=tmp_path,piece_count=pieces,world_id='green_valley',
                    level_id='1-6',resolution=960,title='Watermill',approved_rights=True,
                    total_seconds=1800,three_star_seconds=900,two_star_seconds=1440)
    path=build_laravel_package(cfg,title_ar='الطاحونة')
    report=verify_laravel_archive(path)
    assert report.passed, report.checks
    with zipfile.ZipFile(path) as z:
        v=json.loads(z.read('manifest.json'))
        assert len(z.namelist())==pieces*2+3
        assert all(p['target_rect_px'][2]==p['target_rect_px'][3] for p in v['pieces'])
        assert len({p['image_path'] for p in v['pieces']})==pieces
        assert v['master_image_path']=='master.png'
        assert v['cell_size_px']==960//int(pieces**.5)
        assert v['piece_ordering']=='row_major'
        assert v['reward_policy']=='calculated_on_server_not_in_asset_manifest'
        assert all(p['id']==f'piece_{i:03d}' and p['index']==i for i,p in enumerate(v['pieces']))
        assert all(p['image_path']==f'{pieces}_pieces/{p["id"]}.png' for p in v['pieces'])
        assert all(p['mask_path']==f'{pieces}_masks_svg/{p["id"]}.svg' for p in v['pieces'])
        assert v['padding_px']==(44 if pieces==36 else round(960/int(pieces**.5)*.275))
        assert v['snap_threshold_board_px']==35


def test_missing_required_metadata_blocks(sample,tmp_path):
    def f(name,data):
        if name=='level.json':
            m=json.loads(data);del m['two_star_seconds'];return json.dumps(m).encode()
        return data
    report=verify_laravel_archive(tamper(sample,tmp_path/'missing.zip',transform=f))
    assert not report.passed
    assert any(c['name'].startswith('All 9') and not c['passed'] for c in report.checks)


def test_wrong_manifest_board_size_blocks(sample,tmp_path):
    def f(name,data):
        if name=='manifest.json':
            m=json.loads(data);m['board_size_px']=[1024,1024];return json.dumps(m).encode()
        return data
    assert not verify_laravel_archive(tamper(sample,tmp_path/'board.zip',transform=f)).passed


def test_missing_svg_mask_blocks(sample,tmp_path):
    assert not verify_laravel_archive(tamper(sample,tmp_path/'mask.zip',drop=('16_masks_svg/piece_000.svg',))).passed


def test_modified_opaque_pixels_detected(sample,tmp_path):
    def f(name,data):
        if name=='16_pieces/piece_005.png':
            im=Image.open(BytesIO(data)).convert('RGBA')
            px=im.load();px[im.width//2,im.height//2]=(255,0,255,255)
            b=BytesIO();im.save(b,format='PNG');return b.getvalue()
        return data
    assert not verify_laravel_archive(tamper(sample,tmp_path/'pixel.zip',transform=f)).passed


def test_path_traversal_blocked(sample,tmp_path):
    out=tmp_path/'traversal.zip'
    with zipfile.ZipFile(sample) as zin,zipfile.ZipFile(out,'w') as zout:
        for n in zin.namelist():zout.writestr(n,zin.read(n))
        zout.writestr('../escape.json','{}')
    assert not verify_laravel_archive(out).passed


def test_invalid_server_level_id_rejected(art,tmp_path):
    cfg=BuildConfig(image_path=art,output_dir=tmp_path,piece_count=16,world_id='green_valley',
                    level_id='1-6',title='Watermill',approved_rights=True)
    with pytest.raises(ValueError,match='level_id'):
        build_laravel_package(cfg,backend_level_id='1-6')


def test_invalid_display_code_rejected(art,tmp_path):
    cfg=BuildConfig(image_path=art,output_dir=tmp_path,piece_count=16,world_id='green_valley',
                    level_id='1-6',display_code='GV-006',title='Watermill',approved_rights=True)
    with pytest.raises(ValueError,match='display_code'):
        build_laravel_package(cfg)


def test_fake_svg_mask_detected_even_when_valid_xml(sample,tmp_path):
    def f(name,data):
        if name=='16_masks_svg/piece_001.svg':
            return b'<svg xmlns="http://www.w3.org/2000/svg"><path d="M 0 0 L 1 0 L 1 1 L 0 1 Z"/></svg>'
        return data
    report=verify_laravel_archive(tamper(sample,tmp_path/'fake-mask.zip',transform=f))
    assert not report.passed
    assert any('SVG mask differs' in c.get('detail','') for c in report.checks)


def test_screenshot_exact_36_piece_manifest_layout(art,tmp_path):
    cfg=BuildConfig(image_path=art,output_dir=tmp_path,piece_count=36,world_id='green_valley',
                    level_id='1-6',title='Watermill',approved_rights=True)
    target=build_laravel_package(cfg,title_ar='الطاحونة')
    with zipfile.ZipFile(target) as z:
        manifest=json.loads(z.read('manifest.json'))
        names=set(z.namelist())
        assert {'master.png','manifest.json','level.json'} <= names
        assert manifest['cell_size_px']==160 and manifest['padding_px']==44
        assert manifest['piece_ordering']=='row_major'
        assert manifest['snap_threshold_board_px']==35
        assert len(names)==75
        assert manifest['pieces'][0]['target_rect_px']==[-44,-44,248,248]
        assert manifest['pieces'][0]['snap_anchor_px']==[0,0]
        assert manifest['pieces'][-1]['target_rect_px']==[756,756,248,248]
        assert manifest['pieces'][-1]['snap_anchor_px']==[800,800]
        assert manifest['pieces'][0]['image_path']=='36_pieces/piece_000.png'
        assert manifest['pieces'][-1]['mask_path']=='36_masks_svg/piece_035.svg'
    assert verify_laravel_archive(target).passed

def test_noncanonical_asset_paths_rejected(sample,tmp_path):
    def f(name,data):
        if name=='manifest.json':
            m=json.loads(data);m['pieces'][0]['image_path']='pieces/p000.png';return json.dumps(m).encode()
        return data
    assert not verify_laravel_archive(tamper(sample,tmp_path/'wrong-path.zip',transform=f)).passed

def test_missing_index_rejected(sample,tmp_path):
    def f(name,data):
        if name=='manifest.json':
            m=json.loads(data);m['pieces'][0].pop('index');return json.dumps(m).encode()
        return data
    assert not verify_laravel_archive(tamper(sample,tmp_path/'wrong-index.zip',transform=f)).passed

def test_extra_files_rejected(sample,tmp_path):
    with zipfile.ZipFile(sample) as src,zipfile.ZipFile(tmp_path/'extra.zip','w') as dst:
        for filename in src.namelist():dst.writestr(filename,src.read(filename))
        dst.writestr('qa/build-info.json','{}')
    assert not verify_laravel_archive(tmp_path/'extra.zip').passed
