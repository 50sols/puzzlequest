"""Offline level-package builder. No network, server credentials or admin tokens."""
from __future__ import annotations

from dataclasses import dataclass
from datetime import datetime, timezone
from hashlib import sha256
from io import BytesIO
import json
import math
import os
from pathlib import Path
import re
import shutil
import tempfile
from typing import Callable
from uuid import uuid4
import zipfile

from PIL import Image, ImageDraw, ImageOps

from . import __version__
from .geometry import create_board, normalized_polygon
from .quality import check_shapes_and_coverage, check_serialized_geometry, validate_archive

Progress = Callable[[int, str], None]
VALID_PIECES = (16, 36, 64, 100)
SLUG = re.compile(r"^[a-z0-9][a-z0-9_-]{1,99}$")
LEVEL = re.compile(r"^[0-9]+-[0-9]+$")
DISPLAY_CODE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")


@dataclass(frozen=True)
class BuildConfig:
    image_path: Path
    output_dir: Path
    piece_count: int = 36
    world_id: str = "green_valley"
    level_id: str = "1-6"
    display_code: str | None = None  # Human-visible code; default is level_id.
    position: int | None = None  # Ordering index; default is stage number in level_id (1-6 -> 6).
    title: str = "New Puzzle"
    resolution: int = 1024
    image_mode: str = "crop"  # crop or contain
    total_seconds: int = 600
    three_star_seconds: int = 210
    two_star_seconds: int = 420
    prerequisite_level_id: str | None = None
    min_stars: int = 1
    approved_rights: bool = False

    def validate(self) -> None:
        if not self.image_path.is_file():
            raise ValueError("Select an existing PNG, JPG, or WebP image")
        if self.image_path.suffix.lower() not in (".png", ".jpg", ".jpeg", ".webp"):
            raise ValueError("Image format must be PNG, JPG, JPEG, or WebP")
        if self.image_path.stat().st_size > 35_000_000:
            raise ValueError("Image file must not exceed 35MB")
        if self.piece_count not in VALID_PIECES:
            raise ValueError(f"Supported piece counts: {VALID_PIECES}")
        if not SLUG.fullmatch(self.world_id) or not LEVEL.fullmatch(self.level_id):
            raise ValueError("World: lowercase slug or underscores; level: 1-2 format")
        if self.display_code is not None and not DISPLAY_CODE.fullmatch(self.display_code):
            raise ValueError("Display code must use letters, digits, dots, dashes or underscores (1-64 characters)")
        if self.position is not None and (type(self.position) is not int or not 1 <= self.position <= 1000000):
            raise ValueError("Position must be an integer from 1 to 1000000")
        if self.prerequisite_level_id is not None and not LEVEL.fullmatch(self.prerequisite_level_id):
            raise ValueError("Prerequisite must be empty or in 1-2 format")
        if self.resolution not in (512, 960, 1024, 2048):
            raise ValueError("Resolution must be 512, 960, 1024, or 2048")
        if self.image_mode not in ("crop", "contain"):
            raise ValueError("Image fit must be crop or contain")
        if not (0 < self.three_star_seconds < self.two_star_seconds < self.total_seconds <= 86400):
            raise ValueError("Timer: 0 < 3-star < 2-star < total (up to 24 hours)")
        launch = {"1-1": (16, 360, 150, 270), "1-2": (16, 360, 150, 270),
                  "1-3": (36, 600, 270, 450), "1-4": (64, 1080, 480, 840),
                  "1-5": (100, 1800, 900, 1440)}
        if self.world_id in ("green-valley", "green_valley") and self.level_id in launch:
            actual = (self.piece_count, self.total_seconds, self.three_star_seconds, self.two_star_seconds)
            if actual != launch[self.level_id]:
                raise ValueError(f"Locked launch level {self.level_id} requires (pieces,total,3star,2star) "
                                 f"= {launch[self.level_id]}; use a new level ID for custom settings")
        if not (0 <= self.min_stars <= 3):
            raise ValueError("Min stars must be 0-3")
        if not self.title.strip() or len(self.title) > 120:
            raise ValueError("Title must be between 1 and 120 characters")
        if not self.approved_rights:
            raise ValueError("You must confirm rights to use and publish this image")


def _save_json(path: Path, data: dict) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(data, ensure_ascii=False, sort_keys=True, indent=2) + "\n", encoding="utf-8")


def _digest(path: Path) -> str:
    digest = sha256()
    with path.open("rb") as f:
        for chunk in iter(lambda: f.read(1024*1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def _prepare_image(path: Path, res: int, mode: str) -> Image.Image:
    with Image.open(path) as src:
        src = ImageOps.exif_transpose(src)
        if src.width < 256 or src.height < 256:
            raise ValueError("Source image must be at least 256px wide and high")
        if src.width * src.height > 40_000_000:
            raise ValueError("Source image exceeds safe pixel limit (40 megapixels)")
        rgba = src.convert("RGBA")
        # Fill transparent sources with neutral fantasy-friendly background.
        background = Image.new("RGBA", rgba.size, (239, 243, 247, 255))
        src = Image.alpha_composite(background, rgba).convert("RGB")
    if mode == "crop":
        return ImageOps.fit(src, (res, res), method=Image.Resampling.LANCZOS, centering=(.5, .5))
    return ImageOps.pad(src, (res, res), method=Image.Resampling.LANCZOS,
                        color=(239, 243, 247), centering=(.5, .5))


def _write_binary_pieces(root: Path, img: Image.Image, geom, progress: Progress) -> tuple[list[dict], list[Image.Image], list[Image.Image]]:
    count = geom.rows * geom.cols
    pieces: list[dict] = []
    masks: list[Image.Image] = []
    colored: list[Image.Image] = []
    (root / "pieces").mkdir(exist_ok=True)
    (root / "masks").mkdir(exist_ok=True)
    for idx, points in enumerate(geom.polygons):
        row, col = divmod(idx, geom.cols)
        piece_id = f"p{idx:03d}"
        xs, ys = [p[0] for p in points], [p[1] for p in points]
        # 2px antialias padding; clip to source image and never invent pixels.
        x0 = max(0, int(math.floor(min(xs))) - 2)
        y0 = max(0, int(math.floor(min(ys))) - 2)
        x1 = min(img.width, int(math.ceil(max(xs))) + 3)
        y1 = min(img.height, int(math.ceil(max(ys))) + 3)
        size = (x1 - x0, y1 - y0)
        scale = 2
        mask_hi = Image.new("L", (size[0]*scale, size[1]*scale), 0)
        draw = ImageDraw.Draw(mask_hi)
        polygon = [((px-x0)*scale, (py-y0)*scale) for px, py in points]
        draw.polygon(polygon, fill=255)
        alpha = mask_hi.resize(size, Image.Resampling.LANCZOS)
        alpha.save(root / "masks" / f"{piece_id}.png", optimize=True)
        crop = img.crop((x0, y0, x1, y1)).convert("RGBA")
        crop.putalpha(alpha)
        crop.save(root / "pieces" / f"{piece_id}.webp", format="WEBP", lossless=True, method=4)
        pieces.append({
            "id": piece_id, "row": row, "col": col, "grid": [row, col],
            "sourceRect": [round(x0/img.width, 7), round(y0/img.height, 7),
                           round(size[0]/img.width, 7), round(size[1]/img.height, 7)],
            "target": [round(col/geom.cols, 7), round(row/geom.rows, 7)],
            "bboxPx": [x0, y0, x1, y1],
            "anchorPx": [round(col*img.width/geom.cols, 5),round(row*img.height/geom.rows, 5)],
            "imagePath": f"pieces/{piece_id}.webp",
            "maskPath": f"masks/{piece_id}.png",
            "shape": f"geometry.json#/pieces/{piece_id}",
        })
        masks.append(alpha)
        colored.append(crop)
        if idx % max(1, count // 12) == 0 or idx == count - 1:
            progress(15 + int((idx+1) / count * 58), f"Generated {idx+1}/{count} actual jigsaw pieces")
    return pieces, masks, colored


def _draw_qa_preview(img: Image.Image, geom, output: Path) -> None:
    # All outlines are taken from the EXACT shared edges used to raster masks.
    artwork = img.copy().convert("RGBA")
    overlay = Image.new("RGBA", img.size, (0,0,0,0))
    draw = ImageDraw.Draw(overlay)
    stroke = max(1, img.width // 500)
    for row in geom.horizontal:
        for edge in row:
            draw.line(edge, fill=(25, 26, 48, 180), width=stroke, joint="curve")
    for row in geom.vertical:
        for edge in row:
            draw.line(edge, fill=(25, 26, 48, 180), width=stroke, joint="curve")
    artwork = Image.alpha_composite(artwork, overlay).convert("RGB")
    artwork.thumbnail((750,750))
    artwork.save(output, format="WEBP", quality=89, method=4)


def build_package(cfg: BuildConfig, progress: Progress | None = None) -> Path:
    """Build, independently verify, then atomically deliver exactly one ZIP.

    A failed Quality Gate never leaves a releasable archive in the output folder.
    """
    callback = progress or (lambda percent, detail: None)
    cfg.validate()
    cfg.output_dir.mkdir(parents=True, exist_ok=True)
    revision = str(uuid4())
    revision_short = revision[:8]
    target = cfg.output_dir / f"PuzzleQuest-{cfg.world_id}-{cfg.level_id}-{revision_short}.zip"
    callback(2, f"New immutable Revision UUID: {revision}")
    with tempfile.TemporaryDirectory(prefix="pq-studio-") as temp:
        root = Path(temp) / "content"
        root.mkdir()
        (root / "images").mkdir()
        img = _prepare_image(cfg.image_path, cfg.resolution, cfg.image_mode)
        img.save(root / "images" / "original.webp", format="WEBP", quality=95, method=5)
        # Derive pieces from the exact decoded file shipped in the ZIP.
        with Image.open(root / "images" / "original.webp") as source:
            img = source.convert("RGB")
        preview = img.copy()
        preview.thumbnail((720,720))
        preview.save(root / "images" / "preview.webp", format="WEBP", quality=90)
        thumb = img.copy()
        thumb.thumbnail((320,320))
        thumb.save(root / "images" / "thumbnail.webp", format="WEBP", quality=85)
        callback(12, "Prepared original, preview and thumbnail")
        rows = int(math.isqrt(cfg.piece_count))
        geom = create_board(img.width, img.height, rows, rows, seed=int(revision.replace("-", "")[:14],16))
        pieces, masks, colored = _write_binary_pieces(root, img, geom, callback)
        geom_json = {
            "schemaVersion": "1.0.0", "revisionUuid": revision, "coordinateSystem": "image-pixels",
            "imageSize": [img.width, img.height], "gridRows": rows, "gridCols": rows,
            "horizontalEdges": [[[[round(x,8),round(y,8)] for x,y in e] for e in row] for row in geom.horizontal],
            "verticalEdges": [[[[round(x,8),round(y,8)] for x,y in e] for e in row] for row in geom.vertical],
            "pieces": {p["id"]: {"bboxPx": p["bboxPx"], "polygonNormalized": normalized_polygon(poly,img.width,img.height),
                                    "target": p["target"]} for p,poly in zip(pieces,geom.polygons)},
        }
        _save_json(root / "geometry.json", geom_json)
        _draw_qa_preview(img, geom, root / "images" / "board-preview.webp")
        callback(76, "Running geometry, alpha-mask and image-coverage Quality Gate")
        qa = check_shapes_and_coverage(img, pieces, masks, colored)
        topology_qa = check_serialized_geometry(
            {"difficulty": {"gridRows": rows, "gridCols": rows}, "pieces": pieces},
            geom_json, masks, img.width, img.height)
        qa.checks.extend(topology_qa.checks)
        qa.passed = qa.passed and topology_qa.passed
        if not qa.passed:
            fails = "; ".join(c["detail"] for c in qa.checks if not c["passed"])
            raise ValueError(f"Quality Gate blocked export: {fails}")
        # The deployed Admin/Module/3 importer looks for metadata.level_id.
        # Keep canonical camelCase keys alongside snake_case transport metadata.
        # All copies must agree and are bound to this immutable Revision UUID.
        content_revision = f"{cfg.world_id}-{cfg.level_id}-{revision}"
        display_code = cfg.display_code or cfg.level_id
        # Position is the 1-based display order, not a geometry coordinate.
        # The live importer explicitly requires metadata.position.
        position = cfg.position if cfg.position is not None else int(cfg.level_id.rsplit("-", 1)[1])
        if not 1 <= position <= 1000000:
            raise ValueError("Position must be between 1 and 1000000")
        # The count is derived from actual generated pieces, not a label or
        # editable JSON field. Gate the count before any payload is written.
        if len(pieces) != cfg.piece_count or cfg.piece_count != rows * rows:
            raise ValueError("Quality Gate blocked export: actual piece count differs from grid")
        metadata = {
            "level_id": cfg.level_id,
            "display_code": display_code,
            "position": position,
            "world_id": cfg.world_id,
            "revision_uuid": revision,
            "content_revision": content_revision,
            "title": cfg.title.strip(),
            "piece_count": len(pieces),
            "grid_rows": rows,
            "grid_cols": rows,
            # Live dashboard error (2026-11-26): Missing metadata
            # level_time_limit_seconds. Derived from exactly the same values
            # already serialized in timer.*. Additional transparent aliases
            # are draft compatibility hints, NOT confirmed backend requirements.
            "level_time_limit_seconds": cfg.total_seconds,
            "time_limit_seconds": cfg.total_seconds,
            "three_star_elapsed_max_seconds": cfg.three_star_seconds,
            "two_star_elapsed_max_seconds": cfg.two_star_seconds,
            "level_three_star_elapsed_max_seconds": cfg.three_star_seconds,
            "level_two_star_elapsed_max_seconds": cfg.two_star_seconds,
            "prerequisite_level_id": cfg.prerequisite_level_id,
            "unlock_min_stars": cfg.min_stars,
            "image_width": img.width,
            "image_height": img.height,
            "image_path": "images/original.webp",
            "image_sha256": _digest(root / "images" / "original.webp"),
            "schema_version": "1.0.0",
        }
        # Some admin importers project metadata keys from the document root,
        # rather than from its nested 'metadata' object. Emit BOTH views from
        # one immutable dict to avoid omissions and value drift.
        aliases = dict(metadata)
        manifest = {
            "metadata": metadata,
            **aliases,
            "level_id": cfg.level_id, "display_code": display_code, "position": position, "world_id": cfg.world_id, "revision_uuid": revision,
            "schemaVersion": "1.0.0", "revisionUuid": revision,
            "contentRevision": content_revision,
            "worldId": cfg.world_id, "levelId": cfg.level_id, "title": cfg.title.strip(),
            "difficulty": {"gridRows":rows,"gridCols":rows,"pieceCount":cfg.piece_count},
            "timer": {"totalSeconds":cfg.total_seconds,
                      "threeStarElapsedMax":cfg.three_star_seconds,
                      "twoStarElapsedMax":cfg.two_star_seconds},
            "image": {"assetPath": "images/original.webp", "sha256": _digest(root/"images"/"original.webp"),
                      "dimensions": [img.width,img.height], "previewPath":"images/preview.webp",
                      "thumbnailPath":"images/thumbnail.webp"},
            "pieces": pieces,
            "unlock": {"prerequisiteLevelId": cfg.prerequisite_level_id, "minStars": cfg.min_stars},
            "geometryPath": "geometry.json",
            "publishing": {"state": "draft", "publishedAt": None},
        }
        _save_json(root / "level-manifest.draft.json", manifest)
        # Dashboard Module 3 requires these exact names at ZIP root.
        # The existing draft manifest is kept for older local clients; both are byte-identical.
        _save_json(root / "level.json", manifest)
        _save_json(root / "qa" / "quality-gate.json", qa.as_dict())
        _save_json(root / "build-info.json", {"generator": "PuzzleQuest Studio", "version":__version__,
                                                "createdAt": datetime.now(timezone.utc).isoformat(),
                                                "revisionUuid": revision, "sourceFileName":cfg.image_path.name,
                                                "sourceSha256": _digest(cfg.image_path),
                                                "assetRightsConfirmed": cfg.approved_rights})
        # Module 3 asks for manifest.json, level.json, image, pieces and masks.
        # This is a compatibility envelope, NOT a claim of compatibility with
        # undocumented server-side JSON schema. The manifest covers every
        # preexisting asset; checksum/package files are written afterward.
        stage_files = sorted(p for p in root.rglob("*") if p.is_file())
        stage_hashes = {p.relative_to(root).as_posix(): {"sha256": _digest(p), "bytes":p.stat().st_size}
                        for p in stage_files}
        dashboard_manifest = {
            "metadata": metadata,
            **aliases,
            "level_id": cfg.level_id, "display_code": display_code, "position": position, "world_id": cfg.world_id, "revision_uuid": revision,
            "schemaVersion": "1.0.0",
            "packageType": "puzzlequest.level",
            "revisionUuid": revision,
            "contentRevision": manifest["contentRevision"],
            "worldId": cfg.world_id,
            "levelId": cfg.level_id,
            "pieceCount": cfg.piece_count,
            "levelFile": "level.json",
            "imagePath": "images/original.webp",
            "publishingState": "draft",
            "assets": stage_hashes,
            "files": stage_hashes,
        }
        _save_json(root / "manifest.json", dashboard_manifest)
        # SHA index excludes package.json to prevent circular hashes.
        assetpaths = sorted(p for p in root.rglob("*") if p.is_file())
        checks = {p.relative_to(root).as_posix(): {"sha256": _digest(p), "bytes":p.stat().st_size}
                  for p in assetpaths}
        _save_json(root / "checksums.json", checks)
        checks["checksums.json"] = {"sha256":_digest(root/"checksums.json"),
                                     "bytes":(root/"checksums.json").stat().st_size}
        package = {"schemaVersion":"1.0.0", "packageType":"puzzlequest.level",
                   "metadata": metadata,
                   **aliases,
                   "level_id": cfg.level_id, "display_code": display_code, "position": position, "world_id": cfg.world_id, "revision_uuid": revision,
                   "revisionUuid":revision,"contentRevision":manifest["contentRevision"],
                   "publishingState":"draft", "worldId":cfg.world_id,"levelId":cfg.level_id,
                   "pieceCount":cfg.piece_count,"manifestPath":"level-manifest.draft.json",
                   "importProtocol":"puzzlequest-draft-import-v1", "files":checks}
        _save_json(root / "package.json", package)
        callback(88, "Writing ZIP and verifying its contents independently")
        zipped = Path(temp) / "package.zip"
        with zipfile.ZipFile(zipped, mode="w", compression=zipfile.ZIP_DEFLATED, compresslevel=6, allowZip64=True) as zf:
            for path in sorted(root.rglob("*")):
                if path.is_file():
                    zf.write(path, arcname=path.relative_to(root).as_posix())
        final_report = validate_archive(str(zipped))
        if not final_report.passed:
            problems = "; ".join(c["name"] + ": " + c["detail"] for c in final_report.checks if not c["passed"])
            raise ValueError("Archive validation failed; export blocked: " + problems)
        # Prevent replacing a previously generated revision (UUID collision is practically impossible).
        with target.open("xb") as out, zipped.open("rb") as inp:
            shutil.copyfileobj(inp, out)
        callback(100, f"VALIDATED {len(pieces)}-piece ZIP: {target.name}")
    return target
