#!/usr/bin/env python3
"""Reproducible SOURCE/ASSET verification only, not a Flutter build."""
from __future__ import annotations
from pathlib import Path
import hashlib, json, re, csv, zipfile
ROOT=Path(__file__).resolve().parents[1]
RESULT=ROOT/'DOC03_STATIC_VALIDATION.json'
checks=[]
def check(label,ok,details=''):
    checks.append({'test':label,'passed':bool(ok),'details':details})
    print(('PASS' if ok else 'FAIL'),label,details)

source=ROOT/'assets/config/design_tokens.approved.v1.json'
original=json.loads(source.read_text())
colors=original['colors']
theme=(ROOT/'lib/core/theme.dart').read_text()
for name,key in [('background','background'),('surface','surface'),('primary','primary'),('purple','purple'),
                 ('gold','accent'),('danger','error'),('success','success'),('actionGreen','action_green'),
                 ('white','text'),('muted','muted_text')]:
    hexa='0xFF'+colors[key].lstrip('#').upper()
    check('approved_color_'+name,bool(re.search(rf'\b{name}\s*=\s*Color\({hexa}\)',theme)),hexa)
button_dir=ROOT/'assets/ui/buttons'
for family in ('primary','success','neutral','danger'):
    for state in ('normal','pressed','focused','loading','disabled'):
        file=button_dir/f'{family}_{state}.png'
        check(f'button_{family}_{state}',file.is_file() and file.read_bytes().startswith(b'\x89PNG\r\n\x1a\n'))
with (ROOT/'docs/DOC03_COMPONENT_MATRIX.csv').open(encoding='utf8') as f:
    components=list(csv.DictReader(f))
check('20_components',len(components)==20)
check('all_component_classes',all(item['Dart implementation'].split('(')[0].split(' + ')[0] in
    ((ROOT/'lib/widgets/component_library.dart').read_text() +
     (ROOT/'lib/game/puzzle_board.dart').read_text()) for item in components))
for file in ('lib/widgets/component_library.dart','lib/widgets/component_preview.dart',
             'test/component_contract_test.dart','tool/component_gallery_main.dart'):
    check('exists_'+file,(ROOT/file).is_file())
gradle=(ROOT/'android/gradle/wrapper/gradle-wrapper.properties').read_text()
settings=(ROOT/'android/settings.gradle.kts').read_text()
app=(ROOT/'android/app/build.gradle.kts').read_text()
check('gradle_8_14_3','gradle-8.14.3-all.zip' in gradle)
check('agp_8_13_2','version "8.13.2"' in settings)
check('kgp_2_3_0','version "2.3.0"' in settings)
check('java17_compilerOptions','compilerOptions' in app and 'JVM_17' in app and
      'kotlinOptions' not in app)
check('resource_shrink_compatible','isShrinkResources = false' in app and 'isMinifyEnabled = false' in app)
pub=(ROOT/'pubspec.yaml').read_text()
check('share_plus_13_3_1','share_plus: ^13.3.1' in pub)
check('game_version','version: 1.2.0+5' in pub)
check('artwork_assets_declared','assets/ui/buttons/' in pub)
check('production_api', 'https://puzzlequest.50sols.com/api/v1/' in
      (ROOT/'lib/core/api.dart').read_text())
check('40_screen_ids',all(f'{i}:' in (ROOT/'lib/screens/screens.dart').read_text() for i in range(1,41)))
level_cat=json.loads((ROOT/'assets/config/level_catalog.json').read_text())
check('5_levels',len(level_cat['levels'])==5)
for lv in level_cat['levels']:
    folder=lv['level_folder'];pieces=lv['selected_piece_count']
    man=ROOT/'assets/puzzles'/folder/f'{pieces}.manifest.v1.json'
    if man.exists():
        manifest=json.loads(man.read_text())
        ok=len(manifest.get('pieces',[]))==pieces and all((man.parent/x['image_path']).is_file() for x in manifest['pieces'])
    else:ok=False
    check('manifest_'+str(lv['display_code']),ok, str(pieces)+' pieces')
result={'kind':'STATIC_SOURCE_ASSET_CHECK_ONLY','version':'1.2.0+5',
        'passed':all(x['passed'] for x in checks),'checks':checks,
        'limitations':['No Dart SDK / Flutter analyze or tests executed here',
                       'No Android/iOS build executed here',
                       'No real production authentication or rewards test',
                       'No owner signed golden tests']}
RESULT.write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
print('DOC03 static check:', 'PASS' if result['passed'] else 'FAIL',len(checks),'checks')
raise SystemExit(0 if result['passed'] else 1)
