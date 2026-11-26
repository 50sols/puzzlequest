#!/usr/bin/env python3
"""Verify that the complete PuzzleQuest Game source is present.

Standard-library only. Does not run Flutter, install packages or contact a server.
"""
from pathlib import Path
import re, sys
ROOT=Path(__file__).resolve().parent.parent
REQUIRED=[
    'lib/main.dart', 'lib/core/api.dart', 'lib/core/models.dart',
    'lib/core/content.dart', 'lib/core/session.dart', 'lib/core/push_service.dart',
    'lib/core/ads_service.dart', 'lib/core/offline_journal.dart',
    'lib/core/theme.dart', 'lib/game/gameplay.dart',
    'lib/game/puzzle_board.dart', 'lib/game/timed_preview.dart',
    'lib/screens/screens.dart', 'lib/widgets/pq_widgets.dart',
    'lib/widgets/verified_level_image.dart',
    'lib/widgets/component_library.dart', 'pubspec.yaml',
    'assets/config/design_tokens.approved.v1.json',
    'assets/config/component_governance.v1.json',
]

def check():
    problems=[]
    for rel in REQUIRED:
        if not (ROOT/rel).is_file(): problems.append('MISSING '+rel)
    for file in list((ROOT/'lib').rglob('*.dart'))+list((ROOT/'test').rglob('*.dart')):
        text=file.read_text(encoding='utf-8')
        for raw in re.findall(r"(?m)^\s*(?:import|export|part)\s+['\"]([^'\"]+)['\"]",text):
            if raw.startswith(('dart:','package:flutter/','package:flutter_test/')): continue
            if raw.startswith('package:puzzlequest_game/'):
                target=ROOT/'lib'/raw[len('package:puzzlequest_game/'):].split('?',1)[0]
            elif raw.startswith(('package:','flutter:')): continue  # external packages
            else: target=file.parent/raw.split('?',1)[0]
            if not target.is_file():
                problems.append(f'BROKEN IMPORT {file.relative_to(ROOT)} -> {raw}')
    for rel in ['assets/config','assets/branding','assets/images','assets/fonts','assets/puzzles','assets/ui/buttons']:
        if not (ROOT/rel).is_dir(): problems.append('MISSING DIRECTORY '+rel)
    # verify Flutter asset declarations refer to real directories or files
    pub=(ROOT/'pubspec.yaml')
    if pub.is_file():
        data=pub.read_text(encoding='utf-8')
        for name in re.findall(r'(?m)^\s+- asset:\s*(assets/[^\s#]+)\s*$',data):
            if not (ROOT/name).is_file(): problems.append('MISSING FONT '+name)
        for name in re.findall(r'(?m)^\s+- (assets/[^\s#]+/)\s*$',data):
            if not (ROOT/name).is_dir(): problems.append('MISSING ASSETS '+name)
    print('PuzzleQuest source integrity:', 'PASS' if not problems else 'FAIL')
    print('Dart files:',len(list((ROOT/'lib').rglob('*.dart'))),' in lib; tests:',len(list((ROOT/'test').glob('*.dart'))))
    for p in problems: print(' -',p)
    return not problems

if __name__=='__main__': sys.exit(0 if check() else 1)
