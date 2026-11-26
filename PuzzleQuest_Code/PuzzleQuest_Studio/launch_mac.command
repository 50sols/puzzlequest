#!/bin/bash
cd "$(dirname "$0")" || exit 1
python3 bootstrap.py
result=$?
if [ "$result" -ne 0 ]; then
  echo "Startup failed; review the error above and README_AR.md"
  read -r -p "Press Enter to close..." _
fi
exit "$result"
