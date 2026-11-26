#!/bin/bash
set -e
cd "$(dirname "$0")"
python3 bootstrap.py --install-only
./.venv/bin/python -m pip install --disable-pip-version-check pyinstaller
./.venv/bin/python -m PyInstaller --noconfirm --clean --windowed --name PuzzleQuestStudio launch.py
echo 'App bundle: dist/PuzzleQuestStudio.app'
