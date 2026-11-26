"""Independent content QA: checksums, mask integrity, geometry and cover."""
from __future__ import annotations

from dataclasses import dataclass
from collections import deque
from hashlib import sha256
from io import BytesIO
import json
import re
from pathlib import PurePosixPath
from uuid import UUID
import zipfile

import numpy as np
from PIL import Image, ImageDraw, ImageStat


@dataclass
class QualityReport:
    passed: bool
    checks: list[dict]

    def add(self, name: str, passed: bool, detail: str) -> None:
        self.checks.append({"name": name, "passed": bool(passed), "detail": detail})
        if not passed:
            self.passed = False

    def as_dict(self) -> dict:
        return {"passed": self.passed, "checks": self.checks,
                "passedCount": sum(x["passed"] for x in self.checks),
                "failedCount": sum(not x["passed"] for x in self.checks)}


def _single_connected_shape(mask: Image.Image) -> bool:
    # Efficient downsampled topology check; full-res coverage is tested separately.
    small = mask.copy()
    small.thumbnail((96, 96), Image.Resampling.NEAREST)
    binary = np.asarray(small, dtype=np.uint8) > 127
    ys, xs = np.where(binary)
    if not len(xs):
        return False
    h, w = binary.shape
    seen = np.zeros((h, w), dtype=np.bool_)
    frontier = deque([(int(ys[0]), int(xs[0]))])
    seen[ys[0], xs[0]] = True
    count = 0
    while frontier:
        y, x = frontier.popleft()
        count += 1
        for dy, dx in ((-1, 0), (1, 0), (0, -1), (0, 1)):
            ny, nx = y + dy, x + dx
            if 0 <= ny < h and 0 <= nx < w and binary[ny, nx] and not seen[ny, nx]:
                seen[ny, nx] = True
                frontier.append((ny, nx))
    return count == int(np.count_nonzero(binary))


def check_shapes_and_coverage(
    original: Image.Image, pieces: list[dict], masks: list[Image.Image],
    rgba_pieces: list[Image.Image] | None = None,
) -> QualityReport:
    report = QualityReport(True, [])
    w, h = original.size
    expected = len(pieces)
    report.add("Unique piece IDs", len({p["id"] for p in pieces}) == expected,
               f"{expected} IDs found")
    cells = [(p["row"], p["col"]) for p in pieces]
    report.add("Unique piece locations", len(set(cells)) == expected,
               f"{len(set(cells))} distinct target cells")
    cover = np.zeros((h, w), dtype=np.uint16)
    owner = np.zeros((h, w), dtype=np.uint8)
    geometry_ok = True
    masks_ok = True
    texture_ok = True
    image_mapping_ok = True
    connected = True
    original_rgb = np.asarray(original.convert("RGB"))
    for i, (piece, mask) in enumerate(zip(pieces, masks)):
        x, y, right, bottom = piece["bboxPx"]
        if not (0 <= x < right <= w and 0 <= y < bottom <= h and mask.size == (right-x, bottom-y)):
            geometry_ok = False
            continue
        alpha = np.asarray(mask.convert("L"), dtype=np.uint8)
        if alpha.max() != 255 or (alpha > 127).sum() < 64:
            masks_ok = False
        if not _single_connected_shape(mask):
            connected = False
        view = cover[y:bottom, x:right]
        view += alpha.astype(np.uint16)
        owner[y:bottom, x:right] += (alpha > 127).astype(np.uint8)
        if rgba_pieces is not None:
            rgba = rgba_pieces[i]
            if rgba.size != mask.size or rgba.mode != "RGBA":
                texture_ok = False
            elif not np.array_equal(np.asarray(rgba.getchannel("A")), alpha):
                texture_ok = False
            else:
                opaque = alpha >= 250
                piece_rgb = np.asarray(rgba.convert("RGB"))
                source_crop = original_rgb[y:bottom,x:right]
                if not np.array_equal(piece_rgb[opaque], source_crop[opaque]):
                    image_mapping_ok = False
    report.add("Valid geometry + bounding boxes", geometry_ok, "All crops inside board")
    report.add("Valid alpha masks", masks_ok, "Every piece has a nonempty lossless mask")
    report.add("Connected jigsaw silhouettes", connected, "No disconnected shape islands")
    if rgba_pieces is not None:
        report.add("Piece alpha = mask alpha", texture_ok, "Lossless WebP transparency matches PNG masks")
        report.add("Piece pixels match source image", image_mapping_ok, "Opaque piece pixels match source exactly")
    empty = int(np.count_nonzero(cover < 200))
    # Pixel-level overlap along a shared antialiased boundary is normal. A broad
    # overlaid region is not; count only pixels owned strongly by 3+ pieces.
    over = int(np.count_nonzero(owner >= 3))
    coverage_ok = empty == 0 and over <= max(8, expected // 2)
    report.add("Complete image coverage", coverage_ok,
               f"uncovered pixels={empty}, triple-overlap pixels={over}, dimensions={w}x{h}")
    rms = ImageStat.Stat(original.convert("RGB")).stddev
    report.add("Source contains visual detail", max(rms) >= 3.0,
               "RGB standard deviation: " + ", ".join(f"{x:.2f}" for x in rms))
    return report


def check_serialized_geometry(level: dict, geometry: dict, masks: list[Image.Image],
                              width: int, height: int) -> QualityReport:
    """Audit serialized topology and ensure mask planes match the actual edge geometry."""
    report = QualityReport(True, [])
    rows = level["difficulty"]["gridRows"]
    cols = level["difficulty"]["gridCols"]
    horiz = geometry.get("horizontalEdges", [])
    vert = geometry.get("verticalEdges", [])
    basics = (geometry.get("imageSize") == [width, height] and
              geometry.get("gridRows") == rows and geometry.get("gridCols") == cols and
              len(horiz) == rows + 1 and all(len(r) == cols for r in horiz) and
              len(vert) == rows and all(len(r) == cols + 1 for r in vert))
    report.add("Geometry grid dimensions", basics, "Edge maps must match image/grid dimensions")
    if not basics:
        return report
    endpoints_ok = True
    tabbed_ok = True
    for r, row in enumerate(horiz):
        for c, edge in enumerate(row):
            if not edge or any(len(pt)!=2 or not all(isinstance(v,(int,float)) for v in pt) for pt in edge):
                endpoints_ok=False
                continue
            endpoints_ok &= (abs(edge[0][0]-c*width/cols) < .001 and abs(edge[0][1]-r*height/rows) < .001 and
                             abs(edge[-1][0]-(c+1)*width/cols) < .001 and abs(edge[-1][1]-r*height/rows) < .001)
            deviation = max(abs(y-r*height/rows) for x,y in edge)
            if 0 < r < rows and deviation < height/rows * .1:
                tabbed_ok = False
            if r in (0,rows) and deviation > 0.001:
                tabbed_ok = False
    for r, row in enumerate(vert):
        for c, edge in enumerate(row):
            if not edge or any(len(pt)!=2 or not all(isinstance(v,(int,float)) for v in pt) for pt in edge):
                endpoints_ok=False
                continue
            endpoints_ok &= (abs(edge[0][0]-c*width/cols) < .001 and abs(edge[0][1]-r*height/rows) < .001 and
                             abs(edge[-1][0]-c*width/cols) < .001 and abs(edge[-1][1]-(r+1)*height/rows) < .001)
            deviation = max(abs(x-c*width/cols) for x,y in edge)
            if 0 < c < cols and deviation < width/cols * .1:
                tabbed_ok = False
            if c in (0,cols) and deviation > 0.001:
                tabbed_ok = False
    report.add("Complementary shared edge endpoints", endpoints_ok,
               "Every neighbor shares the same sampled boundary at exact cell corners")
    report.add("Actual interlocking tabs + flat outer frame", tabbed_ok,
               "Internal borders have tabs and holes; outer frame is flat")
    polygon_ok = True
    raster_ok = True
    serial_pieces = geometry.get("pieces", {})
    level_pieces = level["pieces"]
    if set(serial_pieces) != {p["id"] for p in level_pieces}:
        polygon_ok = False
    else:
        for idx, item in enumerate(level_pieces):
            r,c = item["row"],item["col"]
            if not 0 <= r < rows or not 0 <= c < cols:
                polygon_ok = False
                break
            edges = [horiz[r][c],vert[r][c+1],list(reversed(horiz[r+1][c])),list(reversed(vert[r][c]))]
            polygon = []
            for edge in edges:
                polygon.extend(edge if not polygon else edge[1:])
            expected = [[round(x/width,7),round(y/height,7)] for x,y in polygon]
            stored = serial_pieces[item["id"]]
            serial_polygon = stored.get("polygonNormalized", [])
            same_polygon = (len(serial_polygon) == len(expected) and
                            all(len(a) == 2 and all(abs(a[k]-b[k]) <= 1.5e-7 for k in (0,1))
                                for a,b in zip(serial_polygon,expected)))
            polygon_ok &= (same_polygon and
                           stored.get("bboxPx") == item["bboxPx"] and
                           stored.get("target") == item["target"])
            if not polygon_ok:
                continue
            x0,y0,x1,y1 = item["bboxPx"]
            scale = 2
            hi = Image.new("L", ((x1-x0)*scale,(y1-y0)*scale),0)
            ImageDraw.Draw(hi).polygon([((x-x0)*scale,(y-y0)*scale) for x,y in polygon],fill=255)
            expected_alpha = np.asarray(hi.resize((x1-x0,y1-y0),Image.Resampling.LANCZOS),dtype=np.int16)
            actual = np.asarray(masks[idx],dtype=np.int16)
            # Rounding serialized points to 8 decimals can cause sub-pixel differences.
            mismatch = int(np.count_nonzero(abs(expected_alpha - actual) > 4))
            if mismatch > max(8,int(expected_alpha.size*.001)):
                raster_ok = False
    report.add("Per-piece serialized polygons and targets", polygon_ok,
               "Every piece polygon equals a composition of its four shared board edges")
    report.add("Mask pixels correspond to geometry", raster_ok,
               "Regenerated alpha masks match serialized cut paths")
    return report


def check_uuid4(value: str) -> bool:
    try:
        u = UUID(value)
        return u.version == 4 and str(u) == value
    except (ValueError, TypeError):
        return False


def sha_bytes(data: bytes) -> str:
    return sha256(data).hexdigest()


def validate_archive(path: str, *, max_zip_bytes: int = 450_000_000) -> QualityReport:
    """Re-verify an exported ZIP without trusting its embedded QA report."""
    q = QualityReport(True, [])
    with zipfile.ZipFile(path, "r") as z:
        entries = z.infolist()
        names = [i.filename for i in entries if not i.is_dir()]
        safe = (len(names) == len(set(names)) and len(names) <= 310 and
                sum(i.file_size for i in entries) <= max_zip_bytes and
                all(not i.is_dir() and ((i.external_attr >> 16) & 0o170000) != 0o120000 and
                    not i.filename.startswith("/") and "\\" not in i.filename and
                    not any(p in ("..", "") for p in PurePosixPath(i.filename).parts) and
                    i.file_size <= 60_000_000 for i in entries))
        q.add("Safe ZIP entries", safe, f"{len(names)} files; reject traversal, symlinks, oversized/duplicate entries")
        if not safe:
            return q
        try:
            pkg = json.loads(z.read("package.json"))
            level = json.loads(z.read("level-manifest.draft.json"))
            geometry = json.loads(z.read("geometry.json"))
        except (KeyError, ValueError, UnicodeError) as exc:
            q.add("Required JSON metadata", False, str(exc))
            return q
        # Independently enforce the two filenames required by the actual dashboard page.
        try:
            dashboard_level = json.loads(z.read("level.json"))
            dashboard_manifest = json.loads(z.read("manifest.json"))
            names_expected = set(names) - {"package.json", "manifest.json", "checksums.json"}
            dashboard_files = dashboard_manifest.get("assets", {})
            # Manifest must describe the exact contents present when it was written.
            compat_ok = (dashboard_level == level and
                         dashboard_manifest.get("revisionUuid") == pkg.get("revisionUuid") and
                         dashboard_manifest.get("worldId") == pkg.get("worldId") and
                         dashboard_manifest.get("levelId") == pkg.get("levelId") and
                         dashboard_manifest.get("pieceCount") == pkg.get("pieceCount") and
                         dashboard_manifest.get("levelFile") == "level.json" and
                         dashboard_manifest.get("imagePath") == "images/original.webp" and
                         isinstance(dashboard_files, dict) and
                         set(dashboard_files) == names_expected and
                         dashboard_manifest.get("files") == dashboard_files)
            if compat_ok:
                for asset_name, asset_meta in dashboard_files.items():
                    data = z.read(asset_name)
                    if not isinstance(asset_meta, dict) or asset_meta.get("sha256") != sha_bytes(data) or asset_meta.get("bytes") != len(data):
                        compat_ok = False
                        break
            q.add("Dashboard level.json and manifest.json contract", compat_ok,
                  "Exact root filenames; matching revision, level and full SHA-256 asset index")
            # Structural check matching the observed live server error:
            # "Missing metadata level_id". No guesswork on this specific key.
            metadata = dashboard_manifest.get("metadata")
            metadata_ok = (isinstance(metadata, dict) and
                           metadata.get("level_id") == pkg.get("levelId") == dashboard_level.get("levelId") and
                           isinstance(metadata.get("display_code"), str) and
                           bool(re.fullmatch(r"[A-Za-z0-9][A-Za-z0-9._-]{0,63}", metadata["display_code"])) and
                           type(metadata.get("position")) is int and 1 <= metadata["position"] <= 1000000 and
                           metadata.get("world_id") == pkg.get("worldId") == dashboard_level.get("worldId") and
                           metadata.get("revision_uuid") == pkg.get("revisionUuid") == dashboard_level.get("revisionUuid") and
                           metadata.get("piece_count") == pkg.get("pieceCount") == dashboard_level.get("difficulty",{}).get("pieceCount") and
                           metadata.get("image_path") == dashboard_manifest.get("imagePath") and
                           metadata.get("image_sha256") == dashboard_level.get("image",{}).get("sha256") and
                           metadata.get("grid_rows") == dashboard_level.get("difficulty",{}).get("gridRows") and
                           metadata.get("grid_cols") == dashboard_level.get("difficulty",{}).get("gridCols") and
                           all(doc.get("metadata") == metadata and
                               doc.get("level_id") == metadata["level_id"] and
                               doc.get("display_code") == metadata["display_code"] and
                               doc.get("position") == metadata["position"] and
                               doc.get("world_id") == metadata["world_id"] and
                               doc.get("revision_uuid") == metadata["revision_uuid"]
                               for doc in (dashboard_level, dashboard_manifest, pkg)))
            q.add("Dashboard metadata + position + UUID aliases", metadata_ok,
                  "level_id, display_code, 1-based integer position, and UUID match across all JSON records")
            # The live importer has also returned 'Missing metadata piece_count'.
            # Older Studio ZIPs already included metadata.piece_count but did
            # NOT include the snake_case root alias. Require both views here.
            # Verify the exact count and integer type against the actual array,
            # unique piece IDs, and physical mask/piece entries, not just labels.
            nested = (metadata if isinstance(metadata, dict) else {})
            declared_count = nested.get("piece_count")
            n_rows = nested.get("grid_rows")
            n_cols = nested.get("grid_cols")
            actual_pieces = dashboard_level.get("pieces", [])
            piece_ids = [p.get("id") for p in actual_pieces if isinstance(p, dict)] if isinstance(actual_pieces, list) else []
            root_aliases_ok = (
                type(declared_count) is int and declared_count in (16, 36, 64, 100) and
                type(n_rows) is int and type(n_cols) is int and
                declared_count == n_rows * n_cols == len(piece_ids) and
                len(piece_ids) == len(set(piece_ids)) and
                sum(1 for n in names if re.fullmatch(r"pieces/p[0-9]{3}\.webp", n)) == declared_count and
                sum(1 for n in names if re.fullmatch(r"masks/p[0-9]{3}\.png", n)) == declared_count and
                all(isinstance(doc, dict) and isinstance(doc.get("metadata"), dict) and
                    all(k in doc and k in doc["metadata"] and doc[k] == doc["metadata"][k]
                        for k in nested) and
                    type(doc.get("piece_count")) is int and doc["piece_count"] == declared_count and
                    doc.get("pieceCount", declared_count) == declared_count
                    for doc in (dashboard_level, dashboard_manifest, pkg, level))
            )
            q.add("Dashboard root + nested piece_count and physical tile count", root_aliases_ok,
                  f"metadata={declared_count!r}; grid={n_rows!r}x{n_cols!r}; actual={len(piece_ids)}; all transport JSON must agree")
            # Validate newly observed server requirement independently. Reject
            # absent, bool, float, zero, or values drifting across transport
            # documents / timer. Do not trust embedded QA report or hashes.
            declared_time = nested.get("level_time_limit_seconds")
            declared_three = nested.get("three_star_elapsed_max_seconds")
            declared_two = nested.get("two_star_elapsed_max_seconds")
            lvl_timer = dashboard_level.get("timer", {})
            time_ok = (
                type(declared_time) is int and 1 <= declared_time <= 86400 and
                type(declared_three) is int and type(declared_two) is int and
                0 < declared_three < declared_two < declared_time and
                lvl_timer.get("totalSeconds") == declared_time and
                lvl_timer.get("threeStarElapsedMax") == declared_three and
                lvl_timer.get("twoStarElapsedMax") == declared_two and
                nested.get("time_limit_seconds") == declared_time and
                nested.get("level_three_star_elapsed_max_seconds") == declared_three and
                nested.get("level_two_star_elapsed_max_seconds") == declared_two and
                nested.get("image_width") == dashboard_level.get("image",{}).get("dimensions", [None,None])[0] and
                nested.get("image_height") == dashboard_level.get("image",{}).get("dimensions", [None,None])[1] and
                nested.get("prerequisite_level_id") == dashboard_level.get("unlock",{}).get("prerequisiteLevelId") and
                nested.get("unlock_min_stars") == dashboard_level.get("unlock",{}).get("minStars") and
                all(isinstance(doc.get("metadata"), dict) and
                    all(doc.get(key) == nested[key] and doc["metadata"].get(key) == nested[key]
                        for key in (
                            "level_time_limit_seconds", "time_limit_seconds",
                            "three_star_elapsed_max_seconds", "two_star_elapsed_max_seconds",
                            "level_three_star_elapsed_max_seconds", "level_two_star_elapsed_max_seconds",
                            "prerequisite_level_id", "unlock_min_stars", "image_width", "image_height"))
                    for doc in (dashboard_level, dashboard_manifest, pkg, level))
            )
            q.add("Dashboard time-limit metadata + timer parity", time_ok,
                  f"time={declared_time!r}, star3={declared_three!r}, star2={declared_two!r}; all JSON documents must match")
        except (KeyError, ValueError, UnicodeError, TypeError) as exc:
            q.add("Dashboard level.json and manifest.json contract", False,
                  "Missing or invalid required dashboard JSON: " + str(exc))
        q.add("Package contract", pkg.get("packageType") == "puzzlequest.level" and
              pkg.get("schemaVersion") == "1.0.0" and pkg.get("publishingState") == "draft",
              "Requires PuzzleQuest draft import v1")
        rid = pkg.get("revisionUuid")
        q.add("Revision UUIDv4", check_uuid4(rid) and level.get("revisionUuid") == rid and
              geometry.get("revisionUuid") == rid,
              str(rid))
        declared = pkg.get("files", {})
        listed = set(names) - {"package.json"}
        hashes_ok = (isinstance(declared, dict) and listed == set(declared))
        if hashes_ok:
            for name, meta in declared.items():
                if not isinstance(meta, dict) or sha_bytes(z.read(name)) != meta.get("sha256") or len(z.read(name)) != meta.get("bytes"):
                    hashes_ok = False
                    break
        q.add("SHA-256 + size all files", hashes_ok, f"{len(declared)} indexed assets")
        rows = level.get("difficulty", {}).get("gridRows", 0)
        cols = level.get("difficulty", {}).get("gridCols", 0)
        count = level.get("difficulty", {}).get("pieceCount", 0)
        actual = level.get("pieces", [])
        grid_ok = isinstance(rows, int) and isinstance(cols, int) and rows == cols and rows in (4,6,8,10) and count == rows*cols == len(actual)
        q.add("Supported grid + exact count", grid_ok, f"{rows}x{cols}: {len(actual)} pieces")
        timer = level.get("timer", {})
        q.add("Valid star timer thresholds", 0 < timer.get("threeStarElapsedMax",0) < timer.get("twoStarElapsedMax",0) < timer.get("totalSeconds",0),
              str(timer))
        names_set = set(names)
        assets_ok = grid_ok and all("pieces/" + p["id"] + ".webp" in names_set and
                 "masks/" + p["id"] + ".png" in names_set for p in actual)
        q.add("Every piece + mask included", assets_ok, f"{len(actual)} pairs")
        if not (grid_ok and assets_ok and hashes_ok):
            return q
        with Image.open(BytesIO(z.read("images/original.webp"))) as im:
            orig = im.convert("RGB")
        imsz_ok = [orig.width,orig.height] == level.get("image",{}).get("dimensions")
        q.add("Image size matches manifest", imsz_ok, f"{orig.width}x{orig.height}")
        masks = []
        colored = []
        for p in actual:
            with Image.open(BytesIO(z.read("masks/"+p["id"]+".png"))) as m:
                masks.append(m.convert("L"))
            with Image.open(BytesIO(z.read("pieces/"+p["id"]+".webp"))) as im:
                colored.append(im.convert("RGBA"))
        geometry_report = check_serialized_geometry(level, geometry, masks, orig.width, orig.height)
        q.checks.extend(geometry_report.checks)
        q.passed = q.passed and geometry_report.passed
        cover = check_shapes_and_coverage(orig, actual, masks, colored)
        q.checks.extend(cover.checks)
        q.passed = q.passed and cover.passed
        # Check normalized target coordinates and tile indices against grid.
        targets_ok = all(p["row"] in range(rows) and p["col"] in range(cols) and
                         abs(p["target"][0] - p["col"]/cols) < 1e-7 and
                         abs(p["target"][1] - p["row"]/rows) < 1e-7 for p in actual)
        q.add("Canonical snap targets", targets_ok, "Unique (row,col) and normalized (x,y) targets")
    return q
