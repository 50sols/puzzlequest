#!/usr/bin/env python3
"""Restore the owner's original UI fonts from an archive they already have.

The Game source archive deliberately omits font binaries. This tool never
fetches fonts from the web and never writes outside the Game/assets/fonts path.
"""
from pathlib import Path
import hashlib, sys, zipfile
ROOT=Path(__file__).resolve().parents[1]
NAMES=('Tajawal-Regular.ttf','Tajawal-Medium.ttf','Tajawal-Bold.ttf',
       'Lato-Regular.ttf','Lato-Bold.ttf')

def main():
    if len(sys.argv)<2:
        raise SystemExit('Usage: python3 tool/restore_owner_fonts.py /path/to/your/previous_PuzzleQuest_source.zip')
    source=Path(sys.argv[1]).expanduser()
    if not source.is_file() or not zipfile.is_zipfile(source):
        raise SystemExit('Please provide the original user-owned PuzzleQuest Game source ZIP.')
    with zipfile.ZipFile(source) as archive:
        files=archive.namelist()
        for name in NAMES:
            suffix='/PuzzleQuest_Code/Game/assets/fonts/'+name
            matches=[n for n in files if n.endswith(suffix)]
            if len(matches)!=1:raise SystemExit(f'Expected precisely one original font file: {name}; got {len(matches)}')
            data=archive.read(matches[0]);dst=ROOT/'assets/fonts'/name
            dst.parent.mkdir(parents=True,exist_ok=True)
            dst.write_bytes(data)
            print(name,hashlib.sha256(data).hexdigest())
    print('Fonts restored from the original owner-provided archive.')
if __name__=='__main__': main()
