"""Standard-library-only launcher: create a private venv and install missing packages.

This intentionally does NOT import Pillow, numpy, or the graphical app before
checking the environment. Windows launch_windows.bat calls this entry point.
"""
from __future__ import annotations

import argparse
import os
from pathlib import Path
import subprocess
import sys
import venv

ROOT = Path(__file__).resolve().parent
ENV_DIR = ROOT / ".venv"
REQUIREMENTS = ROOT / "requirements.txt"


class StartupError(Exception):
    pass


def venv_python(folder: Path = ENV_DIR) -> Path:
    if os.name == "nt":
        return folder / "Scripts" / "python.exe"
    return folder / "bin" / "python"


def run_checked(argv: list[str], explanation: str) -> None:
    print("[PuzzleQuest Studio] " + explanation, flush=True)
    try:
        completed = subprocess.run(argv, cwd=str(ROOT), check=False)
    except OSError as exc:
        raise StartupError(f"{explanation} could not start: {exc}") from exc
    if completed.returncode != 0:
        raise StartupError(f"{explanation} failed (exit code {completed.returncode}).")


def dependencies_available(interpreter: Path) -> bool:
    # Check imports on the *target interpreter*, not the Python running bootstrap.
    # Tkinter is part of the official python.org Windows Python distribution.
    check = (
        "import tkinter; import PIL; import numpy; "
        "from PIL import Image, ImageOps, ImageTk; "
        "from puzzlequest_studio.gui import main"
    )
    try:
        result = subprocess.run(
            [str(interpreter), "-c", check],
            cwd=str(ROOT), stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
            check=False,
        )
    except OSError:
        return False
    return result.returncode == 0


def create_environment(interpreter: Path) -> None:
    if interpreter.is_file():
        return
    if ENV_DIR.exists():
        # A partially created venv is not safe to reuse. Do not delete user data.
        raise StartupError(
            "The .venv folder exists but its Python interpreter is missing. "
            "Rename or delete ONLY the '.venv' folder, then launch again."
        )
    print("[PuzzleQuest Studio] First launch: creating an isolated .venv...", flush=True)
    try:
        venv.create(ENV_DIR, with_pip=True, system_site_packages=False)
    except (OSError, RuntimeError, subprocess.CalledProcessError) as exc:
        raise StartupError(
            "Could not create Python environment. Install Python 3.10+ from "
            "python.org with the standard venv + pip components. " + str(exc)
        ) from exc
    if not interpreter.is_file():
        raise StartupError("Python environment creation did not produce its interpreter.")


def ensure_ready() -> Path:
    if sys.version_info < (3, 10):
        raise StartupError("Python 3.10 or newer is required. Visit https://www.python.org/downloads/")
    if not REQUIREMENTS.is_file():
        raise StartupError("requirements.txt is missing; re-extract the complete Studio ZIP.")
    try:
        import tkinter  # noqa: F401
    except ImportError as exc:
        raise StartupError(
            "Tkinter is missing in your Python installation. On Windows, "
            "install the full Python package from python.org, including Tcl/Tk."
        ) from exc

    interpreter = venv_python()
    create_environment(interpreter)
    if not dependencies_available(interpreter):
        print("[PuzzleQuest Studio] Installing missing Python packages (first run needs internet)...", flush=True)
        run_checked(
            [str(interpreter), "-m", "pip", "install", "--disable-pip-version-check", "-r", str(REQUIREMENTS)],
            "Dependency installation",
        )
        if not dependencies_available(interpreter):
            raise StartupError(
                "Dependencies still fail to import after pip installation. "
                "Try renaming only the '.venv' folder and launching again. "
                "Check that Python includes Tcl/Tk."
            )
    print("[PuzzleQuest Studio] Dependencies OK. Using " + str(interpreter), flush=True)
    return interpreter


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="One-click PuzzleQuest Studio environment setup")
    parser.add_argument("--install-only", action="store_true", help="Prepare environment without opening GUI")
    args = parser.parse_args(argv)
    try:
        interpreter = ensure_ready()
        if args.install_only:
            return 0
        # Subprocess exit status is the real GUI exit status; this script never
        # imports application dependencies into the wrong interpreter.
        return subprocess.call([str(interpreter), str(ROOT / "launch.py")], cwd=str(ROOT))
    except StartupError as exc:
        print("\n[ERROR] " + str(exc), file=sys.stderr, flush=True)
        print(
            "[HELP] Check your internet on first launch, verify Python 3.10+, "
            "and see README_AR.md (Windows troubleshooting).",
            file=sys.stderr,
            flush=True,
        )
        return 1
    except KeyboardInterrupt:
        print("\n[PuzzleQuest Studio] Cancelled.", file=sys.stderr, flush=True)
        return 130
    except OSError as exc:
        print("\n[ERROR] Unable to open the app: " + str(exc), file=sys.stderr, flush=True)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
