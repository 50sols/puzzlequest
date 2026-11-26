# PuzzleQuest Studio Windows first-run launcher (PowerShell 5.1+).
# No elevation and no user-entered terminal commands are required.
# This script is invoked by the BAT files; do not execute downloaded code.
param(
    [ValidateSet('Run', 'Build')]
    [string] $Mode = 'Run'
)

$ErrorActionPreference = 'Continue'
$root = Split-Path -Parent $PSScriptRoot
$bootstrap = Join-Path $root 'bootstrap.py'
$venvPython = Join-Path $root '.venv\Scripts\python.exe'
$pythonDownload = 'https://www.python.org/downloads/windows/'

function Find-Python {
    # Return the first working Python >=3.10. Do not trust PATH or registry alone:
    # Windows' Microsoft Store execution aliases can masquerade as python.exe.
    $candidates = New-Object 'System.Collections.Generic.List[object]'
    $seen = @{}

    function Add-Candidate([string] $path, [string[]] $prefix) {
        if ([string]::IsNullOrWhiteSpace($path)) { return }
        $key = ($path + '|' + ($prefix -join ':')).ToLowerInvariant()
        if ($seen.ContainsKey($key)) { return }
        $seen[$key] = $true
        $candidates.Add([pscustomobject]@{ File = $path; Prefix = $prefix })
    }

    # Existing virtual environment may still be valid after PATH changes.
    if (Test-Path -LiteralPath $venvPython -PathType Leaf) {
        Add-Candidate $venvPython @()
    }

    # The classic Python Launcher is often installed in Windows, but not on PATH.
    if ($env:WINDIR) { Add-Candidate (Join-Path $env:WINDIR 'py.exe') @('-3') }
    if ($env:LOCALAPPDATA) {
        Add-Candidate (Join-Path $env:LOCALAPPDATA 'Programs\Python\Launcher\py.exe') @('-3')
    }

    foreach ($commandName in @('py.exe', 'python.exe', 'python3.exe')) {
        $commands = @(Get-Command -Name $commandName -CommandType Application -All -ErrorAction SilentlyContinue)
        foreach ($command in $commands) {
            $path = $command.Source
            if ($commandName -eq 'py.exe') { Add-Candidate $path @('-3') }
            else { Add-Candidate $path @() }
        }
    }

    # PEP 514 registries: per-user and machine Python installs often work when
    # the PATH environment variable in this Explorer session has not updated.
    $registryRoots = @(
        'HKCU:\Software\Python\PythonCore',
        'HKLM:\Software\Python\PythonCore',
        'HKLM:\Software\WOW6432Node\Python\PythonCore'
    )
    foreach ($regRoot in $registryRoots) {
        if (-not (Test-Path $regRoot)) { continue }
        foreach ($versionKey in @(Get-ChildItem -LiteralPath $regRoot -ErrorAction SilentlyContinue)) {
            $key = Join-Path $versionKey.PSPath 'InstallPath'
            if (-not (Test-Path -LiteralPath $key)) { continue }
            try {
                $item = Get-Item -LiteralPath $key -ErrorAction Stop
                $exePath = $item.GetValue('ExecutablePath')
                if ($exePath -and (Test-Path -LiteralPath $exePath -PathType Leaf)) {
                    Add-Candidate $exePath @()
                }
                $installFolder = $item.GetValue('')
                if ($installFolder) { Add-Candidate (Join-Path $installFolder 'python.exe') @() }
            } catch { }
        }
    }

    $installationRoots = @()
    if ($env:LOCALAPPDATA) { $installationRoots += (Join-Path $env:LOCALAPPDATA 'Programs\Python') }
    if ($env:ProgramFiles) { $installationRoots += $env:ProgramFiles }
    if (${env:ProgramFiles(x86)}) { $installationRoots += ${env:ProgramFiles(x86)} }

    foreach ($base in $installationRoots) {
        if (-not (Test-Path -LiteralPath $base -PathType Container)) { continue }
        foreach ($folder in @(Get-ChildItem -Path (Join-Path $base 'Python*') -Directory -ErrorAction SilentlyContinue)) {
            Add-Candidate (Join-Path $folder.FullName 'python.exe') @()
        }
    }

    # Find common single-folder installations even if no registry was written.
    if ($env:SystemDrive) {
        foreach ($folder in @(Get-ChildItem -Path (Join-Path $env:SystemDrive '\Python3*') -Directory -ErrorAction SilentlyContinue)) {
            Add-Candidate (Join-Path $folder.FullName 'python.exe') @()
        }
    }

    # A double-clicked .py file can work even when no Python is on PATH.
    # Check its Windows file association as an additional discovery route.
    try {
        $extension = Get-Item -LiteralPath 'Registry::HKEY_CLASSES_ROOT\.py' -ErrorAction Stop
        $fileClass = $extension.GetValue('')
        if ($fileClass -and ($fileClass -match '^[A-Za-z0-9_.-]+$')) {
            $openKey = 'Registry::HKEY_CLASSES_ROOT\' + $fileClass + '\shell\open\command'
            if (Test-Path -LiteralPath $openKey) {
                $commandLine = (Get-Item -LiteralPath $openKey).GetValue('')
                if ($commandLine -match '^\s*"([^"\r\n]+(?:python|py)\.exe)"') {
                    Add-Candidate $matches[1] @()
                }
            }
        }
    } catch { }

    $probe = 'import sys; sys.exit(0 if sys.version_info >= (3,10) else 1)'
    foreach ($candidate in $candidates) {
        try {
            $prefix = [string[]] $candidate.Prefix
            & $candidate.File @prefix -c $probe 1>$null 2>$null
            if ($LASTEXITCODE -eq 0) { return $candidate }
        } catch {
            # An invalid Windows Store alias, orphan registry, or broken PATH
            # must not hide another valid interpreter.
        }
    }
    return $null
}

function Try-InstallPython {
    $installer = Get-Command -Name 'winget.exe' -CommandType Application -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if (-not $installer) {
        Write-Host '[INFO] Windows Package Manager (winget) is unavailable on this machine.' -ForegroundColor Yellow
        return $false
    }
    Write-Host '[SETUP] Python was not detected. Installing official Python 3.13 for this Windows user...' -ForegroundColor Cyan
    Write-Host '[SETUP] Installation requires internet. Windows may ask for a system confirmation.'
    try {
        # Fixed trusted package identifier; winget verifies the package manifest
        # and installer hash. No arbitrary URL / untrusted script is executed.
        & $installer.Source install --id 'Python.Python.3.13' --exact --source winget --scope user --silent --accept-package-agreements --accept-source-agreements
        $code = $LASTEXITCODE
        if ($code -ne 0) {
            Write-Host ('[WARN] Windows Package Manager returned exit code ' + $code + '.') -ForegroundColor Yellow
        }
        # After installation, probe again even for a nonzero return code:
        # an already-installed package can still be usable.
        return $true
    } catch {
        Write-Host ('[WARN] Automatic Python setup could not complete: ' + $_.Exception.Message) -ForegroundColor Yellow
        return $false
    }
}

function Exit-WithHelp {
    Write-Host ''
    Write-Host '[ERROR] Could not locate a usable Python 3.10+ after setup.' -ForegroundColor Red
    Write-Host '[HELP] Official download page: ' $pythonDownload
    Write-Host '[HELP] Install Python with pip, venv, and Tcl/Tk. Then double-click launch_windows.bat again.'
    Write-Host '[HELP] If Windows Package Manager was unavailable, the page will open in your browser.'
    try { Start-Process -FilePath $pythonDownload | Out-Null } catch { }
    exit 10
}

if (-not (Test-Path -LiteralPath $bootstrap -PathType Leaf)) {
    Write-Host '[ERROR] bootstrap.py is missing. Re-extract the complete PuzzleQuest Studio ZIP.' -ForegroundColor Red
    exit 11
}

Write-Host '===================================================='
Write-Host '  PuzzleQuest Studio - Windows one-click setup'
Write-Host '===================================================='
Write-Host ''

$runner = Find-Python
if (-not $runner) {
    [void](Try-InstallPython)
    $runner = Find-Python
}
if (-not $runner) { Exit-WithHelp }

Write-Host ('[OK] Using Python: ' + $runner.File) -ForegroundColor Green
$prefix = [string[]] $runner.Prefix
try {
    if ($Mode -eq 'Build') {
        & $runner.File @prefix $bootstrap --install-only
    } else {
        & $runner.File @prefix $bootstrap
    }
    $code = $LASTEXITCODE
    if ($code -ne 0) {
        Write-Host ('[ERROR] PuzzleQuest Studio setup failed (exit ' + $code + ').') -ForegroundColor Red
        exit $code
    }
} catch {
    Write-Host ('[ERROR] Could not launch Python bootstrap: ' + $_.Exception.Message) -ForegroundColor Red
    exit 12
}

if ($Mode -eq 'Build') {
    if (-not (Test-Path -LiteralPath $venvPython -PathType Leaf)) {
        Write-Host '[ERROR] .venv Python was not created.' -ForegroundColor Red
        exit 13
    }
    Write-Host '[BUILD] Installing PyInstaller into the project environment...'
    & $venvPython -m pip install --disable-pip-version-check 'pyinstaller>=6,<8'
    if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    Push-Location $root
    try {
        & $venvPython -m PyInstaller --noconfirm --clean --onefile --windowed --name PuzzleQuestStudio launch.py
        if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
    } finally { Pop-Location }
    Write-Host ('[SUCCESS] Windows EXE: ' + (Join-Path $root 'dist\PuzzleQuestStudio.exe')) -ForegroundColor Green
}
exit 0
