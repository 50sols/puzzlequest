@echo off
setlocal EnableExtensions
pushd "%~dp0" || (echo [ERROR] Cannot open PuzzleQuest Studio folder. & pause & exit /b 1)
if not exist "%~dp0scripts\windows_launcher.ps1" (
  echo [ERROR] scripts\windows_launcher.ps1 is missing. Copy the full v1.0.2 QuickFix.
  pause
  popd
  exit /b 1
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\windows_launcher.ps1" -Mode Build
set "CODE=%ERRORLEVEL%"
if not "%CODE%"=="0" (
  echo.
  echo [ERROR] EXE build failed. Please read the message above.
  pause
)
popd
exit /b %CODE%
