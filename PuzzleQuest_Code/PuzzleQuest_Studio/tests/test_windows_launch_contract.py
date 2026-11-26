"""Static cross-platform checks of the Windows launcher delivery contract.

The scripts still require a real Windows machine for end-to-end execution.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def test_bat_startup_calls_correct_windows_script_and_preserves_failures():
    bat = read('launch_windows.bat')
    assert 'powershell.exe' in bat
    assert 'scripts\\windows_launcher.ps1' in bat
    assert '-Mode Run' in bat
    assert 'exit /b %CODE%' in bat
    assert 'pause' in bat


def test_auto_install_uses_fixed_winget_package_and_user_scope():
    script = read('scripts/windows_launcher.ps1')
    assert "'Python.Python.3.13'" in script
    assert '--scope user' in script
    assert '--source winget' in script
    assert '--accept-source-agreements' in script
    assert 'Invoke-Expression' not in script
    assert 'DownloadString' not in script


def test_finds_python_without_path_and_reprobes_after_install():
    script = read('scripts/windows_launcher.ps1')
    assert 'HKCU:\\Software\\Python\\PythonCore' in script
    assert 'HKLM:\\Software\\Python\\PythonCore' in script
    assert "'Registry::HKEY_CLASSES_ROOT\\.py'" in script
    assert "'Programs\\Python'" in script
    assert "'py.exe'" in script
    assert script.count('$runner = Find-Python') == 2
    assert script.index('Try-InstallPython)') < script.rindex('$runner = Find-Python')


def test_build_bat_uses_same_python_setup():
    bat = read('build_windows_exe.bat')
    assert 'scripts\\windows_launcher.ps1' in bat
    assert '-Mode Build' in bat
    script = read('scripts/windows_launcher.ps1')
    assert 'PyInstaller' in script
    assert '--install-only' in script
