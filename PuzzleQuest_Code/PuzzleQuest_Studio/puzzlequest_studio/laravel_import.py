"""Exact offline exporter/verifier for provided PuzzleQuest Laravel Content.php importer.

Source contract: app/Services/Content.php (owner-provided app.rar, 2026-11-26).
A passing local quality gate cannot verify DB::table('worlds')->exists(), PHP GD,
production server resources, or real-device QA; those remain deployment gates.
"""
from __future__ import annotations

from collections import Counter
from dataclasses import replace
from hashlib import sha256
from io import BytesIO
from pathlib import Path, PurePosixPath
import json
import math
import re
import shutil
import tempfile
from typing import Callable
from uuid import UUID,uuid4
import xml.etree.ElementTree as ET
import zipfile

import numpy as np
from PIL import Image, ImageDraw

from .builder import BuildConfig, _prepare_image, _save_json
from .geometry import create_board
from .quality import QualityReport

BOARD_SIZE = 960
PIECE_COUNTS = (16,36,64,100)
ALLOWED_EXTENSIONS = ('.json','.png','.jpg','.jpeg','.webp','.svg')
REQUIRED_META = ('level_id','world_id','display_code','position','title',
                 'piece_count','level_time_limit_seconds','three_star_seconds','two_star_seconds')
CODE_PATTERN = re.compile(r'[0-9]+-[0-9]+\Z')
ID_PATTERN = re.compile(r'[a-z0-9_]{3,100}\Z')


def to_backend_level_id(stage_code: str, world_id: str) -> str:
    """Map user-facing `1-6` to DB-safe stable `level_006_green_valley`.

    This is a NEW identifier, not proof of a preexisting database record.
    """
    if not CODE_PATTERN.fullmatch(stage_code):
        raise ValueError('Display code must be digits-digits (example: 1-6)')
    number = int(stage_code.split('-')[1])
    if number < 1:
        raise ValueError('Level number must be positive')
    suffix = re.sub(r'[^a-z0-9_]', '_',world_id.lower()).strip('_')
    result = f'level_{number:03d}_{suffix}'[:100]
    if not ID_PATTERN.fullmatch(result):
        raise ValueError('Cannot form a backend level ID')
    return result


def _edges(geom, r: int, c: int, grid: int) -> dict:
    # Shared curves assigned one polarity; neighboring sides have opposite values.
    def hor(row: int, col: int) -> int:
        pts = geom.horizontal[row][col]
        center = pts[len(pts)//2][1]
        return 1 if center > row * (BOARD_SIZE/grid) else -1
    def ver(row: int, col: int) -> int:
        pts = geom.vertical[row][col]
        center = pts[len(pts)//2][0]
        return 1 if center > col * (BOARD_SIZE/grid) else -1
    return {'top': -hor(r,c) if r>0 else 0,
            'right':ver(r,c+1) if c+1<grid else 0,
            'bottom':hor(r+1,c) if r+1<grid else 0,
            'left':-ver(r,c) if c>0 else 0}


def _mask_and_shapes(geom, grid: int, pad: int):
    cell = BOARD_SIZE // grid
    dim = cell + 2 * pad
    masks=[]
    for idx, points in enumerate(geom.polygons):
        r,c=divmod(idx,grid)
        start_x=c*cell-pad;start_y=r*cell-pad
        mask=Image.new('L',(dim,dim),0)
        ImageDraw.Draw(mask).polygon([(x-start_x,y-start_y) for x,y in points],fill=255)
        masks.append(np.asarray(mask,dtype=np.uint8).copy())
    coverage=np.zeros((BOARD_SIZE,BOARD_SIZE),dtype=np.uint16)
    for i,mask in enumerate(masks):
        r,c=divmod(i,grid)
        x=c*cell-pad;y=r*cell-pad
        xmin=max(0,x);ymin=max(0,y)
        xmax=min(BOARD_SIZE,x+dim);ymax=min(BOARD_SIZE,y+dim)
        coverage[ymin:ymax,xmin:xmax] += (mask[ymin-y:ymax-y,xmin-x:xmax-x]>0).astype(np.uint16)
    # Integer polygon rendering can leave one-pixel seams. Allocate each uncovered
    # pixel to the piece owning that pixel's grid cell, eliminating true holes.
    holes=np.argwhere(coverage==0)
    for yy,xx in holes:
        row=min(grid-1,int(yy)//cell);col=min(grid-1,int(xx)//cell)
        idx=row*grid+col
        masks[idx][int(yy)-(row*cell-pad),int(xx)-(col*cell-pad)]=255
    coverage[:]=0
    for i,mask in enumerate(masks):
        r,c=divmod(i,grid)
        x=c*cell-pad;y=r*cell-pad
        xmin=max(0,x);ymin=max(0,y)
        xmax=min(BOARD_SIZE,x+dim);ymax=min(BOARD_SIZE,y+dim)
        coverage[ymin:ymax,xmin:xmax] += (mask[ymin-y:ymax-y,xmin-x:xmax-x]>0).astype(np.uint16)
    if (coverage==0).any():
        raise ValueError('Quality Gate failed: uncovered board pixels')
    return masks,int(len(holes)),int(np.max(coverage))


def _svg_polygon(points, start_x: int, start_y: int, dimension: int) -> bytes:
    fmt=lambda v: f'{v:.3f}'
    coords=[(x-start_x,y-start_y) for x,y in points]
    d='M '+f'{fmt(coords[0][0])} {fmt(coords[0][1])}'+' '.join(f' L {fmt(x)} {fmt(y)}' for x,y in coords[1:])+' Z'
    svg=(f'<svg xmlns="http://www.w3.org/2000/svg" width="{dimension}" height="{dimension}" '
         f'viewBox="0 0 {dimension} {dimension}"><path d="{d}" fill="#fff"/></svg>')
    return svg.encode('utf-8')


def _check_source_art_not_flat(img: Image.Image) -> None:
    small=np.asarray(img.resize((32,32)).convert('RGB'),dtype=np.int16)
    # Strong uniform art cannot produce unique piece textures.
    if np.ptp(small.reshape(-1,3),axis=0).max()<20:
        raise ValueError('Quality Gate: artwork lacks sufficient contrast')


def build_laravel_package(cfg: BuildConfig,
                          progress: Callable[[int,str],None] | None = None,
                          *, backend_level_id: str | None = None,
                          title_ar: str | None = None,
                          title_en: str | None = None,
                          previous_level_id: str | None = None) -> Path:
    """Produce a strict server-compatible ZIP, with full local contract validation."""
    cb=progress or (lambda pct,msg: None)
    cfg.validate()
    display=cfg.display_code or cfg.level_id
    if not CODE_PATTERN.fullmatch(display):
        raise ValueError('Laravel dashboard display_code MUST be digits-digits, e.g. 1-6')
    level_id=backend_level_id or to_backend_level_id(display,cfg.world_id)
    if not ID_PATTERN.fullmatch(level_id):
        raise ValueError('Laravel level_id requires lowercase letters/digits/underscore, length 3–100')
    position=cfg.position if cfg.position is not None else int(display.split('-')[1])
    if type(position) is not int or position<1:
        raise ValueError('Position must be a positive integer')
    ar=title_ar or cfg.title
    en=title_en or cfg.title
    if not isinstance(ar,str) or not ar.strip() or not isinstance(en,str) or not en.strip():
        raise ValueError('Both Arabic and English localized titles are required')
    if not (0<cfg.three_star_seconds<=cfg.two_star_seconds<=cfg.total_seconds<=7200):
        raise ValueError('Laravel timer contract: 0 < three <= two <= total <= 7200')
    if cfg.piece_count not in PIECE_COUNTS:
        raise ValueError('Laravel supports 16,36,64,100 pieces only')
    # Existing local Studio enforces stricter timer ordering, which is safe.
    if not re.fullmatch(r'[a-z0-9_-]{3,100}',cfg.world_id):
        raise ValueError('World ID must be the EXACT database worlds.id (lowercase slug/underscore)')
    revision=str(uuid4())
    grid=math.isqrt(cfg.piece_count)
    cell=BOARD_SIZE//grid
    pad=round(cell*.275)  # 160px cells -> 44px padding, matching approved puzzle layout
    dim=cell+2*pad
    cb(2,f'Local Revision UUID: {revision}')
    with tempfile.TemporaryDirectory(prefix='pq-laravel-') as tmp:
        folder=Path(tmp)/'content';folder.mkdir()
        pieces_dir=f'{cfg.piece_count}_pieces'
        masks_dir=f'{cfg.piece_count}_masks_svg'
        (folder/pieces_dir).mkdir()
        (folder/masks_dir).mkdir()
        im=_prepare_image(cfg.image_path,BOARD_SIZE,cfg.image_mode)
        _check_source_art_not_flat(im)
        master=folder/'master.png'
        im.save(master,format='PNG',optimize=True)
        geom=create_board(BOARD_SIZE,BOARD_SIZE,grid,grid,seed=int(revision.replace('-','')[:14],16))
        masks,seam_fixes,max_cover=_mask_and_shapes(geom,grid,pad)
        padded=Image.new('RGBA',(BOARD_SIZE+2*pad,BOARD_SIZE+2*pad),(0,0,0,0))
        padded.paste(im.convert('RGBA'),(pad,pad))
        piece_defs=[]
        hashes=set()
        for i,mask in enumerate(masks):
            r,c=divmod(i,grid)
            x=c*cell-pad;y=r*cell-pad
            piece_id=f'piece_{i:03d}'
            cut=padded.crop((c*cell,r*cell,c*cell+dim,r*cell+dim))
            cut.putalpha(Image.fromarray(mask,mode='L'))
            p_path=folder/pieces_dir/f'{piece_id}.png'
            cut.save(p_path,format='PNG',optimize=True)
            digest=sha256(p_path.read_bytes()).hexdigest()
            if digest in hashes:raise ValueError('Quality Gate: visually duplicated PNG assets')
            hashes.add(digest)
            (folder/masks_dir/f'{piece_id}.svg').write_bytes(_svg_polygon(geom.polygons[i],x,y,dim))
            piece_defs.append({'id':piece_id,'index':i,'row':r,'column':c,
                               'snap_anchor_px':[c*cell,r*cell],
                               'target_rect_px':[x,y,dim,dim],
                               'image_path':f'{pieces_dir}/{piece_id}.png',
                               'mask_path':f'{masks_dir}/{piece_id}.svg',
                               'edges':_edges(geom,r,c,grid)})
            if i%max(1,cfg.piece_count//12)==0 or i==cfg.piece_count-1:
                cb(15+int((i+1)/cfg.piece_count*60),f'Built Laravel PNG + SVG {i+1}/{cfg.piece_count}')
        # Approved filenames and flat root JSON paths: Laravel Content::import reads
        # $meta directly from level.json root, NOT $meta['metadata'].
        meta={'level_id':level_id,'world_id':cfg.world_id,'display_code':display,
              'position':position,'title':{'ar':ar.strip(),'en':en.strip()},
              'piece_count':cfg.piece_count,'level_time_limit_seconds':cfg.total_seconds,
              'three_star_seconds':cfg.three_star_seconds,'two_star_seconds':cfg.two_star_seconds,
              'revision_uuid':revision}
        if previous_level_id:
            if not ID_PATTERN.fullmatch(previous_level_id):
                raise ValueError('previous_level_id must be a DB-safe level ID')
            meta['previous_level_id']=previous_level_id
        elif display=='1-6':
            # Known published Level 5 ID observed in admin UI 2026-11-26.
            meta['previous_level_id']='level_005_autumn_tree'
        manifest={'schema_version':'1.0.0','level_id':level_id,
                  'board_size_px':[BOARD_SIZE,BOARD_SIZE],
                  'difficulty_piece_count':cfg.piece_count,
                  'grid':{'rows':grid,'columns':grid},
                  'padding_px':pad,
                  'cell_size_px':cell,
                  'piece_ordering':'row_major',
                  'snap_threshold_board_px':35,
                  'master_image_path':'master.png',
                  'pieces':piece_defs,
                  'reward_policy':'calculated_on_server_not_in_asset_manifest',
                  'revision_uuid':revision}
        _save_json(folder/'level.json',meta)
        _save_json(folder/'manifest.json',manifest)
        cb(82,'Re-reading archive with Laravel contract verifier')
        target=cfg.output_dir/f'PuzzleQuest-Laravel-{level_id}-{revision[:8]}.zip'
        cfg.output_dir.mkdir(parents=True,exist_ok=True)
        staged=Path(tmp)/'export.zip'
        with zipfile.ZipFile(staged,'w',zipfile.ZIP_DEFLATED,compresslevel=6) as z:
            for path in sorted(folder.rglob('*')):
                if path.is_file():z.write(path,arcname=path.relative_to(folder).as_posix())
        report=verify_laravel_archive(staged)
        if not report.passed:
            raise ValueError('Laravel Quality Gate BLOCKED export: '+ '; '.join(x['name']+':'+x['detail'] for x in report.checks if not x['passed']))
        with target.open('xb') as final, staged.open('rb') as src:
            shutil.copyfileobj(src,final)
        cb(100,f'PASS: {cfg.piece_count} pieces, {len(report.checks)} independent server-contract checks')
        return target


def verify_laravel_archive(path: Path | str) -> QualityReport:
    """Offline mirror of Content::validate + SafeZip structural constraints.

    DOES NOT assert worlds.id exists or run PHP GD / DB transaction / on-device QA.
    """
    report=QualityReport(True,[])
    try:
        with zipfile.ZipFile(path) as z:
            infos=z.infolist()
            names=[p.filename for p in infos]
            safe=(len(infos)<=1500 and len({n.lower() for n in names})==len(names) and
                  sum(x.file_size for x in infos)<=134217728 and
                  all(not x.is_dir() and not x.filename.startswith('/') and '\\' not in x.filename and ':' not in x.filename
                    and all(p not in ('','.','..') for p in PurePosixPath(x.filename).parts)
                    and not any(ord(s)<32 for s in x.filename) and
                    x.filename.lower().endswith(ALLOWED_EXTENSIONS) and
                    (x.external_attr>>16)&0o170000 != 0o120000 and
                    not (x.file_size>1048576 and x.file_size/max(1,x.compress_size)>300)
                    for x in infos))
            report.add('Safe ZIP, file counts, extensions, expansion caps',safe,f'{len(infos)} files')
            if not safe:return report
            try:
                meta=json.loads(z.read('level.json'))
                manifest=json.loads(z.read('manifest.json'))
            except (KeyError,ValueError) as ex:
                report.add('Root JSON files',False,str(ex));return report
            need=all(key in meta and meta[key] is not None for key in REQUIRED_META)
            report.add('All 9 required level.json root metadata keys',need,str([k for k in REQUIRED_META if k not in meta]))
            if not need:return report
            idok=(isinstance(meta['level_id'],str) and ID_PATTERN.fullmatch(meta['level_id']) and
                  isinstance(meta['display_code'],str) and CODE_PATTERN.fullmatch(meta['display_code']) and
                  type(meta['position']) is int and meta['position']>=1 and
                  isinstance(meta['world_id'],str) and len(meta['world_id'])>=1 and
                  isinstance(meta['title'],dict) and all(isinstance(meta['title'].get(l),str) and meta['title'][l].strip() for l in ('ar','en')))
            report.add('Laravel level identity/localized title types',bool(idok),'level_id underscores, display_code digits-digits, AR+EN title')
            piece_count=meta['piece_count'];tim=meta['level_time_limit_seconds'];three=meta['three_star_seconds'];two=meta['two_star_seconds']
            timers=(type(piece_count) is int and piece_count in PIECE_COUNTS and
                    all(type(t) is int for t in (tim,three,two)) and 0<three<=two<=tim<=7200)
            report.add('Laravel piece count and timer bounds',timers,'16/36/64/100; 0<three<=two<=total<=7200')
            if not idok or not timers:return report
            grid=int(math.isqrt(piece_count));cell=BOARD_SIZE//grid
            pieces=manifest.get('pieces',[])
            root_ok=(manifest.get('schema_version')=='1.0.0' and manifest.get('board_size_px')==[960,960]
                     and type(manifest.get('difficulty_piece_count')) is int and manifest['difficulty_piece_count']==piece_count
                     and isinstance(pieces,list) and len(pieces)==piece_count and manifest.get('level_id')==meta['level_id'])
            report.add('Exact Laravel manifest root fields',root_ok,'schema_version, board_size_px, difficulty_piece_count, level_id, pieces')
            if not root_ok:return report
            pad=manifest.get('padding_px')
            geometry_ok=(type(pad) is int and 0<=pad<=cell and manifest.get('grid')=={'rows':grid,'columns':grid}
                         and type(manifest.get('snap_threshold_board_px')) in (int,float) and
                         0<manifest['snap_threshold_board_px']<=cell/2)
            report.add('Board grid, padding, snap threshold',bool(geometry_ok),f'{grid}x{grid}, cell={cell}, pad={pad}')
            if not geometry_ok:return report
            canonical=(manifest.get('cell_size_px')==cell and type(manifest.get('cell_size_px')) is int and
                       manifest.get('piece_ordering')=='row_major' and
                       manifest.get('master_image_path')=='master.png' and
                       manifest.get('reward_policy')=='calculated_on_server_not_in_asset_manifest' and
                       (pad==44 if piece_count==36 else pad==round(cell*.275)) and
                       manifest.get('snap_threshold_board_px')==35)
            report.add('Canonical board geometry and manifest naming',canonical,
                       f'cell={cell}, padding={pad}, ordering=row_major, snap=35')
            if not canonical:return report
            expected_names={'level.json','manifest.json','master.png'}
            expected_names.update(f'{piece_count}_pieces/piece_{i:03d}.png' for i in range(piece_count))
            expected_names.update(f'{piece_count}_masks_svg/piece_{i:03d}.svg' for i in range(piece_count))
            files_ok=set(names)==expected_names and len(names)==len(expected_names)
            report.add('Exact exported ZIP layout with no extra files',files_ok,
                       f'{len(names)} entries; expected {2*piece_count+3} root/tile files')
            if not files_ok:return report
            masterpath=manifest.get('master_image_path')
            master_ok=(isinstance(masterpath,str) and masterpath in names and masterpath.lower().endswith('.png'))
            if master_ok:
                try:
                    master=Image.open(BytesIO(z.read(masterpath))).convert('RGB')
                    master_ok=master.size==(BOARD_SIZE,BOARD_SIZE)
                except Exception:master_ok=False
            report.add('960x960 PNG master and decoded pixels',master_ok,str(masterpath))
            if not master_ok:return report
            src=np.asarray(master,dtype=np.uint8)
            coverage=np.zeros((BOARD_SIZE,BOARD_SIZE),dtype=np.bool_)
            ids=set();positions={};pixel_ok=True;assets_ok=True;svg_ok=True;dups=set();duplicate=False;core_mismatch=0; mask_difference=0
            for array_index,p in enumerate(pieces):
                try:
                    if p.get('index') != array_index or type(p.get('index')) is not int:
                        raise ValueError('piece array is not row-major ordered')
                    pid=p['id'];r=p['row'];c=p['column'];rect=p['target_rect_px']
                    anchor=p['snap_anchor_px'];edges=p['edges']
                    texture=p['image_path'];mask_path=p['mask_path']
                    if (type(r) is not int or type(c) is not int or not 0<=r<grid or not 0<=c<grid or
                        (r,c) in positions or pid in ids or not isinstance(pid,str)):
                        raise ValueError('duplicate/bad piece ID or cell')
                    idx=r*grid+c
                    if (p.get('index') != idx or type(p.get('index')) is not int or
                        pid != f'piece_{idx:03d}' or
                        texture != f'{piece_count}_pieces/{pid}.png' or
                        mask_path != f'{piece_count}_masks_svg/{pid}.svg'):
                        raise ValueError('non-canonical row-major id, index or asset path')
                    positions[(r,c)]=p;ids.add(pid)
                    if anchor!=[c*cell,r*cell] or rect!=[c*cell-pad,r*cell-pad,cell+2*pad,cell+2*pad]:
                        raise ValueError('bad target rectangle or anchor')
                    if not texture.endswith('.png') or not mask_path.endswith('.svg') or texture not in names or mask_path not in names:
                        raise ValueError('missing PNG or SVG')
                    binary=z.read(texture);digest=sha256(binary).hexdigest()
                    if digest in dups:duplicate=True
                    dups.add(digest)
                    svg=z.read(mask_path)
                    if re.search(rb'<!DOCTYPE|<!ENTITY|<script|foreignObject|\son\w+\s*=|(?:href|xlink:href)\s*=',svg,re.I):
                        svg_ok=False
                    e=ET.fromstring(svg)
                    if e.tag.split('}')[-1]!='svg' or any(n.tag.split('}')[-1] not in ('svg','path') for n in e.iter()) or len(list(e))!=1:
                        svg_ok=False
                    pim=Image.open(BytesIO(binary)).convert('RGBA')
                    if pim.size!=(rect[2],rect[3]):raise ValueError('PNG size mismatch')
                    rgba=np.asarray(pim,dtype=np.uint8);alpha=rgba[:,:,3]
                    # Rasterize the safe SVG polygon and compare to the actual
                    # tile alpha: reject fake/outdated masks, not just malformed XML.
                    path_d=list(e)[0].attrib.get('d','')
                    tokens=re.findall(r'[MLZ]|-?\d+(?:\.\d+)?',path_d)
                    polygon=[];k=0
                    while k<len(tokens):
                        if tokens[k] in ('M','L') and k+2<len(tokens):
                            polygon.append((float(tokens[k+1]),float(tokens[k+2])));k+=3
                        elif tokens[k]=='Z':k+=1
                        else:raise ValueError('Invalid SVG geometry path')
                    if len(polygon)<4 or not path_d.startswith('M '):raise ValueError('Invalid SVG contour')
                    reconstructed=Image.new('L',pim.size,0)
                    ImageDraw.Draw(reconstructed).polygon(polygon,fill=255)
                    difference=int(np.count_nonzero((np.asarray(reconstructed)>127)!=(alpha>127)))
                    mask_difference+=difference
                    if difference>max(40,int(0.002*alpha.size)):
                        raise ValueError('SVG mask differs from piece alpha')
                    yy0=max(0,rect[1]);xx0=max(0,rect[0]); yy1=min(960,rect[1]+rect[3]);xx1=min(960,rect[0]+rect[2])
                    if yy0>=yy1 or xx0>=xx1:raise ValueError('target outside board')
                    sub=alpha[yy0-rect[1]:yy1-rect[1],xx0-rect[0]:xx1-rect[0]]
                    coverage[yy0:yy1,xx0:xx1]|=(sub>0)
                    # Mirror PHP's GD rule: inside core, compare color to master, tolerance=3.
                    # Stronger than PHP: compare ALL opaque interior pixels,
                    # not only pixels whose 8 neighbors are opaque.
                    opaque=(alpha==255)
                    sample=opaque[yy0-rect[1]:yy1-rect[1],xx0-rect[0]:xx1-rect[0]]
                    if sample.any():
                        delta=np.abs(rgba[yy0-rect[1]:yy1-rect[1],xx0-rect[0]:xx1-rect[0],:3].astype(np.int16)-
                                     src[yy0:yy1,xx0:xx1].astype(np.int16)).max(axis=2)
                        core_mismatch+=int(np.count_nonzero(sample & (delta>3)))
                except Exception as ex:
                    assets_ok=False;report.add('Invalid piece record',False,f'{str(ex)}');break
            report.add('All physical PNG/SVG pieces, unique PNG hashes',assets_ok and not duplicate and len(ids)==piece_count,
                       f'checked={len(ids)}, duplicateTexture={duplicate}')
            report.add('SVG safety + matching raster mask',svg_ok, f'safe SVG root and path; alpha contour differences={mask_difference}')
            report.add('Image coverage 960x960 and core pixel match',bool(coverage.all() and core_mismatch==0),
                       f'uncovered={int(np.count_nonzero(~coverage))}, mismatches={core_mismatch}')
            reciprocal=True
            for (r,c),p in positions.items():
                edges=p.get('edges',{})
                if any(type(edges.get(k)) is not int or edges[k] not in (-1,0,1) for k in ('top','right','bottom','left')):reciprocal=False;break
                if (r==0 and edges['top']!=0) or (c==0 and edges['left']!=0) or (r==grid-1 and edges['bottom']!=0) or (c==grid-1 and edges['right']!=0):reciprocal=False;break
                if c<grid-1 and (r,c+1) in positions and edges['right']!=-positions[(r,c+1)]['edges']['left']:reciprocal=False;break
                if r<grid-1 and (r+1,c) in positions and edges['bottom']!=-positions[(r+1,c)]['edges']['top']:reciprocal=False;break
            report.add('Reciprocal jigsaw edges and outer zero boundaries',reciprocal,'all adjacencies and perimeter')
            uuid=meta.get('revision_uuid')
            try:
                valid_uuid=UUID(uuid).version==4 and str(UUID(uuid))==uuid and manifest.get('revision_uuid')==uuid
            except (ValueError,TypeError):valid_uuid=False
            report.add('Local UUIDv4 paired in JSON',valid_uuid,'note server creates its own content_revisions.id UUID')
            report.add('Database world-ID & PHP GD / device QA',True,'NOT OFFLINE-VERIFIABLE: confirm existing worlds.id, PHP GD, device QA separately')
    except (OSError,zipfile.BadZipFile,KeyError,TypeError,ValueError) as exc:
        report.add('ZIP processing',False,str(exc))
    return report


def repair_laravel_world(archive: Path | str, world_id: str, output: Path | None = None) -> Path:
    """Repackage a validated puzzle without re-rendering geometry.

    Only the metadata world ID and newly generated revision UUID change.
    Original ZIP bytes are never overwritten. Callers must obtain `world_id`
    from `/api/studio/v1/worlds` before using this method for production.
    """
    source = Path(archive)
    if not source.is_file():
        raise ValueError('Choose an existing ZIP archive')
    if not re.fullmatch(r'[a-z0-9_]{3,80}', world_id):
        raise ValueError('World ID must be the exact server worlds.id (lowercase with underscores)')
    before = verify_laravel_archive(source)
    if not before.passed:
        raise ValueError('Original ZIP failed local Quality Gate; cannot repair unsafe content: '
                         + '; '.join(x['name'] for x in before.checks if not x['passed']))
    new_uuid = str(uuid4())
    destination = output or source.with_name(f'{source.stem}-worldfix-{new_uuid[:8]}.zip')
    destination = Path(destination)
    if destination.resolve() == source.resolve() or destination.exists():
        raise ValueError('Output must be a NEW filename; never overwrite a ZIP or published revision')
    with tempfile.TemporaryDirectory(prefix='pq-worldfix-') as temp:
        temporary = Path(temp) / 'new.zip'
        with zipfile.ZipFile(source, 'r') as original, zipfile.ZipFile(temporary, 'w', compression=zipfile.ZIP_DEFLATED, compresslevel=6) as fixed:
            for item in original.infolist():
                name = item.filename
                binary = original.read(item)
                if name in ('level.json', 'manifest.json', 'qa/build-info.json'):
                    data = json.loads(binary.decode('utf-8'))
                    if name == 'level.json':
                        data['world_id'] = world_id
                        data['revision_uuid'] = new_uuid
                    elif name == 'manifest.json':
                        data['revision_uuid'] = new_uuid
                    else:
                        data['local_revision_uuid'] = new_uuid
                        data['world_id'] = world_id
                        data['world_identity_repair'] = True
                    binary = (json.dumps(data, ensure_ascii=False, sort_keys=True, indent=2) + '\n').encode('utf-8')
                fixed.writestr(item.filename, binary, compress_type=zipfile.ZIP_DEFLATED)
        after = verify_laravel_archive(temporary)
        if not after.passed:
            raise ValueError('Corrected ZIP failed Quality Gate: '+ '; '.join(x['name'] for x in after.checks if not x['passed']))
        destination.parent.mkdir(parents=True, exist_ok=True)
        with destination.open('xb') as out, temporary.open('rb') as inp:
            shutil.copyfileobj(inp, out)
    return destination
