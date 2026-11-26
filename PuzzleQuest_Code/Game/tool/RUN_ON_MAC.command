#!/bin/zsh
set -e
cd "$(dirname "$0")/.."
if ! command -v flutter >/dev/null 2>&1; then
  echo 'Flutter SDK is missing from PATH'; exit 1
fi
python3 tool/check_source_integrity.py
if [[ ! -f android/gradlew || ! -f android/gradle/wrapper/gradle-wrapper.jar || ! -f ios/Runner.xcodeproj/project.pbxproj ]]; then
  python3 tool/prepare_platforms.py
fi
flutter pub get
flutter analyze
flutter test
flutter devices
# Default to the known local Android emulator only when available.
if flutter devices --machine | grep -q 'emulator-5554'; then
  flutter run -d emulator-5554
else
  echo 'Select the target device ID shown above, then run: flutter run -d DEVICE_ID'
fi
