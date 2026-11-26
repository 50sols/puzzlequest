"""Headless command-line tooling for scripted workflows and CI."""
from __future__ import annotations

import argparse
from pathlib import Path
import sys

from . import __version__
from .builder import BuildConfig, build_package
from .quality import validate_archive
from .laravel_import import build_laravel_package, verify_laravel_archive


def run(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(prog="puzzlequest-studio", description="PuzzleQuest offline ZIP content builder")
    parser.add_argument("--version", action="version", version=__version__)
    sub = parser.add_subparsers(dest="action", required=True)
    b = sub.add_parser("build", help="Build an independently validated draft-level ZIP")
    b.add_argument("--image", required=True, type=Path)
    b.add_argument("--pieces", type=int, choices=(16,36,64,100), default=36)
    b.add_argument("--world", default="green_valley")
    b.add_argument("--level", default="1-6")
    b.add_argument("--backend-level-id", default=None, help="Optional DB-safe levels.id")
    b.add_argument("--title-ar", default=None, help="Arabic title; required for user-facing localization")
    b.add_argument("--previous-level-id", default=None, help="DB-safe prior level ID, not 1-5")
    b.add_argument("--title", default="New Puzzle")
    b.add_argument("--display-code", default=None, help="Public-facing stage code, defaults to --level")
    b.add_argument("--position", type=int, default=None, help="1-based stage order; defaults to numeric level suffix")
    b.add_argument("--output", default="./output", type=Path)
    b.add_argument("--resolution", default=960, choices=(960,), type=int)
    b.add_argument("--fit", default="crop", choices=("crop", "contain"))
    b.add_argument("--timer", default=600, type=int)
    b.add_argument("--three-star", default=210, type=int)
    b.add_argument("--two-star", default=420, type=int)
    b.add_argument("--prerequisite", default=None)
    b.add_argument("--min-stars", default=1, type=int)
    b.add_argument("--rights-confirmed", action="store_true", help="Confirm image usage/publication rights")
    v = sub.add_parser("verify", help="Independently audit an existing PuzzleQuest ZIP")
    v.add_argument("zip_path", type=Path)
    args = parser.parse_args(argv)
    try:
        if args.action == "verify":
            import zipfile, json
            with zipfile.ZipFile(args.zip_path) as z:
                is_laravel=json.loads(z.read('manifest.json')).get('board_size_px') == [960,960]
            report = verify_laravel_archive(args.zip_path) if is_laravel else validate_archive(str(args.zip_path))
            for check in report.checks:
                print(("PASS" if check["passed"] else "FAIL") + "  " + check["name"] + " — " + check["detail"])
            return 0 if report.passed else 2
        cfg = BuildConfig(image_path=args.image, output_dir=args.output, piece_count=args.pieces,
                          world_id=args.world, level_id=args.level, display_code=args.display_code, position=args.position, title=args.title,
                          resolution=args.resolution, image_mode=args.fit,
                          total_seconds=args.timer, three_star_seconds=args.three_star,
                          two_star_seconds=args.two_star, prerequisite_level_id=args.prerequisite,
                          min_stars=args.min_stars, approved_rights=args.rights_confirmed)
        output = build_laravel_package(cfg,
            progress=lambda pct, message: print(f"[{pct:3}%] {message}", flush=True),
            backend_level_id=args.backend_level_id, title_ar=args.title_ar,
            title_en=args.title,previous_level_id=args.previous_level_id)
        print(f"\nSUCCESS: {output}")
        return 0
    except Exception as exc:
        print(f"FAILED: {exc}", file=sys.stderr)
        return 2


if __name__ == "__main__":
    raise SystemExit(run())
