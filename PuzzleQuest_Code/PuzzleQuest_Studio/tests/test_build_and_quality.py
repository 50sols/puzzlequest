from __future__ import annotations

from dataclasses import replace
from io import BytesIO
import json
from pathlib import Path
import zipfile

import pytest
from PIL import Image, ImageDraw

from puzzlequest_studio.builder import BuildConfig, build_package
from puzzlequest_studio.geometry import create_board
from puzzlequest_studio.quality import validate_archive


@pytest.fixture()
def artwork(tmp_path: Path) -> Path:
    out = tmp_path / "art.png"
    image = Image.new("RGB", (550, 490), "#133451")
    d = ImageDraw.Draw(image)
    for x in range(60):
        d.ellipse((x * 10, (x * 37) % 420, x * 10 + 71, (x * 37) % 420 + 60),
                  fill=((x * 13) % 255, (x * 23 + 39) % 255, (x * 31 + 71) % 255))
    image.save(out)
    return out


def config(image: Path, tmp_path: Path, count: int = 16, **kw) -> BuildConfig:
    return BuildConfig(image_path=image, output_dir=tmp_path / "exports",
                       piece_count=count, resolution=512, approved_rights=True, **kw)


@pytest.mark.parametrize("count", [16, 36, 64, 100])
def test_each_supported_grid_passes_full_qa(artwork, tmp_path, count):
    generated = build_package(config(artwork, tmp_path, count))
    report = validate_archive(str(generated))
    assert report.passed, report.as_dict()
    with zipfile.ZipFile(generated) as z:
        package = json.loads(z.read("package.json"))
        level = json.loads(z.read("level-manifest.draft.json"))
        geometry = json.loads(z.read("geometry.json"))
        dashboard_level = json.loads(z.read("level.json"))
        dashboard_manifest = json.loads(z.read("manifest.json"))
        assert dashboard_level == level
        assert dashboard_manifest["metadata"]["level_id"] == "1-6"
        assert dashboard_manifest["metadata"]["display_code"] == "1-6"
        assert dashboard_manifest["metadata"]["position"] == 6
        assert dashboard_level["position"] == dashboard_manifest["position"] == package["position"] == 6
        assert dashboard_level["display_code"] == dashboard_manifest["display_code"] == package["display_code"] == "1-6"
        assert dashboard_level["metadata"] == package["metadata"] == dashboard_manifest["metadata"]
        assert dashboard_level["level_id"] == dashboard_manifest["level_id"] == package["level_id"] == "1-6"
        assert dashboard_manifest["metadata"]["revision_uuid"] == package["revisionUuid"]
        assert dashboard_manifest["revisionUuid"] == package["revisionUuid"]
        assert dashboard_manifest["levelFile"] == "level.json"
        assert dashboard_manifest["imagePath"] == "images/original.webp"
        assert "level.json" in dashboard_manifest["assets"]
        assert package["revisionUuid"] == level["revisionUuid"] == geometry["revisionUuid"]
        assert level["difficulty"]["pieceCount"] == count
        assert len([n for n in z.namelist() if n.startswith("pieces/")]) == count
        assert len([n for n in z.namelist() if n.startswith("masks/")]) == count
        assert level["publishing"]["state"] == "draft"


def test_revision_uuid_is_unique_on_every_build(artwork, tmp_path):
    a = build_package(config(artwork, tmp_path))
    b = build_package(config(artwork, tmp_path))
    assert a != b
    with zipfile.ZipFile(a) as za, zipfile.ZipFile(b) as zb:
        ra = json.loads(za.read("package.json"))["revisionUuid"]
        rb = json.loads(zb.read("package.json"))["revisionUuid"]
        assert ra != rb


def test_rejects_checksum_tampering(artwork, tmp_path):
    output = build_package(config(artwork, tmp_path))
    malicious = tmp_path / "tampered.zip"
    with zipfile.ZipFile(output) as z, zipfile.ZipFile(malicious, "w") as bad:
        for name in z.namelist():
            data = z.read(name)
            if name == "images/original.webp":
                data += b"extra corruption"
            bad.writestr(name, data)
    report = validate_archive(str(malicious))
    assert not report.passed
    assert any(c["name"] == "SHA-256 + size all files" and not c["passed"] for c in report.checks)


def test_rejects_path_traversal(artwork, tmp_path):
    output = build_package(config(artwork, tmp_path))
    malicious = tmp_path / "traversal.zip"
    with zipfile.ZipFile(output) as z, zipfile.ZipFile(malicious, "w") as bad:
        for name in z.namelist():
            bad.writestr(name, z.read(name))
        bad.writestr("../evil.txt", b"do not write outside")
    report = validate_archive(str(malicious))
    assert not report.passed
    assert report.checks[0]["name"] == "Safe ZIP entries"


def test_rejects_blank_image_and_leaves_no_export(tmp_path):
    image = tmp_path / "blank.png"
    Image.new("RGB", (400,400), "#ffffff").save(image)
    output_dir = tmp_path / "exports"
    with pytest.raises(ValueError, match="Quality Gate blocked export"):
        build_package(config(image, tmp_path))
    assert not list(output_dir.glob("*.zip"))


def test_requires_image_rights(tmp_path, artwork):
    cfg = replace(config(artwork, tmp_path), approved_rights=False)
    with pytest.raises(ValueError, match="right"):
        build_package(cfg)


def test_rejects_inconsistent_piece_count(tmp_path, artwork):
    cfg = replace(config(artwork, tmp_path), piece_count=50)
    with pytest.raises(ValueError, match="Supported piece"):
        build_package(cfg)


def test_launch_levels_locked(tmp_path, artwork):
    with pytest.raises(ValueError, match="Locked launch"):
        build_package(replace(config(artwork, tmp_path), level_id="1-1"))
    output = build_package(replace(config(artwork, tmp_path), level_id="1-1",piece_count=16,
                                   total_seconds=360,three_star_seconds=150,two_star_seconds=270))
    assert output.is_file()


def test_geometry_shared_edges_not_independent(tmp_path):
    geom = create_board(512,512,4,4,seed=1234)
    # A right-side edge and the neighbor's left-side edge share ONE actual
    # reference, with reversal only when used in closed polygons.
    for row in range(4):
        for col in range(1,4):
            boundary = geom.vertical[row][col]
            assert boundary[0] == (col*128,row*128)
            assert boundary[-1] == (col*128,(row+1)*128)
            assert max(abs(x-col*128) for x, y in boundary) > 4


def test_zip_has_no_secrets_or_unsafe_paths(artwork,tmp_path):
    output = build_package(config(artwork,tmp_path))
    with zipfile.ZipFile(output) as z:
        paths=z.namelist()
        assert all(".." not in Path(p).parts for p in paths)
        assert not any(p.endswith(".env") or "token" in p.lower() for p in paths)
        assert all(not p.startswith("/") for p in paths)


def test_detects_missing_piece_even_if_zip_is_repacked(artwork, tmp_path):
    output = build_package(config(artwork, tmp_path))
    broken = tmp_path / "missing-piece.zip"
    with zipfile.ZipFile(output) as src, zipfile.ZipFile(broken, "w") as dest:
        for name in src.namelist():
            if name != "pieces/p005.webp":
                dest.writestr(name, src.read(name))
    result = validate_archive(str(broken))
    assert not result.passed
    assert any(c["name"] == "Every piece + mask included" and not c["passed"] for c in result.checks)


def test_detects_invalid_geometry_despite_recomputed_sha(artwork, tmp_path):
    """A self-consistent SHA index cannot make a semantically incorrect puzzle valid."""
    from hashlib import sha256
    output = build_package(config(artwork, tmp_path))
    broken = tmp_path / "wrong-geometry.zip"
    with zipfile.ZipFile(output) as src:
        contents = {name: src.read(name) for name in src.namelist()}
    geometry = json.loads(contents["geometry.json"])
    geometry["pieces"]["p000"]["polygonNormalized"][0][0] += 0.05
    contents["geometry.json"] = json.dumps(geometry, sort_keys=True).encode()
    hashes = json.loads(contents["checksums.json"])
    hashes["geometry.json"] = {"sha256":sha256(contents["geometry.json"]).hexdigest(),
                                "bytes":len(contents["geometry.json"])}
    contents["checksums.json"] = (json.dumps(hashes, sort_keys=True)+"\n").encode()
    pkg = json.loads(contents["package.json"])
    pkg["files"]["geometry.json"] = hashes["geometry.json"]
    pkg["files"]["checksums.json"] = {"sha256":sha256(contents["checksums.json"]).hexdigest(),
                                      "bytes":len(contents["checksums.json"])}
    contents["package.json"] = json.dumps(pkg).encode()
    with zipfile.ZipFile(broken, "w") as z:
        for name, data in contents.items():
            z.writestr(name, data)
    result = validate_archive(str(broken))
    assert not result.passed
    assert any(c["name"] == "Per-piece serialized polygons and targets" and not c["passed"] for c in result.checks)


@pytest.mark.parametrize("missing", ["level.json", "manifest.json"])
def test_dashboard_required_file_missing_blocks_qa(artwork, tmp_path, missing):
    output = build_package(config(artwork, tmp_path))
    modified = tmp_path / f"without-{missing}.zip"
    with zipfile.ZipFile(output) as source, zipfile.ZipFile(modified, "w") as target:
        for name in source.namelist():
            if name != missing:
                target.writestr(name, source.read(name))
    report = validate_archive(str(modified))
    assert not report.passed
    assert any(x["name"] == "Dashboard level.json and manifest.json contract" and not x["passed"] for x in report.checks)


def test_dashboard_manifest_asset_index_tampering_detected_even_if_package_updated(artwork, tmp_path):
    output = build_package(config(artwork, tmp_path))
    modified = tmp_path / "tampered-dashboard-index.zip"
    import hashlib
    with zipfile.ZipFile(output) as z:
        data = {n:z.read(n) for n in z.namelist()}
    dash = json.loads(data["manifest.json"])
    dash["assets"]["level.json"]["sha256"] = "0" * 64
    data["manifest.json"] = (json.dumps(dash,sort_keys=True,ensure_ascii=False,indent=2)+"\n").encode()
    pkg=json.loads(data["package.json"])
    pkg["files"]["manifest.json"] = {"sha256":hashlib.sha256(data["manifest.json"]).hexdigest(),
                                     "bytes":len(data["manifest.json"])}
    data["package.json"] = (json.dumps(pkg,sort_keys=True,ensure_ascii=False,indent=2)+"\n").encode()
    with zipfile.ZipFile(modified,"w") as z:
        for name, blob in data.items(): z.writestr(name,blob)
    report = validate_archive(str(modified))
    assert not report.passed
    assert any(x["name"] == "Dashboard level.json and manifest.json contract" and not x["passed"] for x in report.checks)


def test_missing_metadata_level_id_is_blocked_even_if_hashes_recomputed(artwork, tmp_path):
    """Live dashboard error must be a local Quality Gate failure too."""
    output = build_package(config(artwork, tmp_path))
    with zipfile.ZipFile(output) as src:
        data = {n:src.read(n) for n in src.namelist()}
    import hashlib
    dashboard = json.loads(data["manifest.json"])
    dashboard["metadata"].pop("level_id")
    data["manifest.json"] = (json.dumps(dashboard,ensure_ascii=False,sort_keys=True,indent=2)+"\n").encode()
    pkg = json.loads(data["package.json"])
    pkg["files"]["manifest.json"] = {"sha256":hashlib.sha256(data["manifest.json"]).hexdigest(),"bytes":len(data["manifest.json"])}
    data["package.json"] = (json.dumps(pkg,ensure_ascii=False,sort_keys=True,indent=2)+"\n").encode()
    damaged = tmp_path / "missing-metadata.zip"
    with zipfile.ZipFile(damaged,"w") as z:
        for name,blob in data.items(): z.writestr(name,blob)
    report=validate_archive(str(damaged))
    assert not report.passed
    assert any(c["name"] == "Dashboard metadata + position + UUID aliases" and not c["passed"] for c in report.checks)


def test_metadata_uuid_mismatch_rejected(artwork,tmp_path):
    output=build_package(config(artwork,tmp_path))
    with zipfile.ZipFile(output) as src:
        data={n:src.read(n) for n in src.namelist()}
    m=json.loads(data["manifest.json"])
    m["metadata"]["revision_uuid"]="00000000-0000-4000-8000-000000000000"
    data["manifest.json"] = (json.dumps(m,ensure_ascii=False,sort_keys=True,indent=2)+"\n").encode()
    pkg=json.loads(data["package.json"])
    import hashlib
    pkg["files"]["manifest.json"]={"sha256":hashlib.sha256(data["manifest.json"]).hexdigest(),"bytes":len(data["manifest.json"])}
    data["package.json"]=(json.dumps(pkg,ensure_ascii=False,sort_keys=True,indent=2)+"\n").encode()
    damaged=tmp_path/"mismatched-uuid.zip"
    with zipfile.ZipFile(damaged,"w") as z:
        for name,blob in data.items():z.writestr(name,blob)
    report=validate_archive(str(damaged))
    assert not report.passed
    assert any(c["name"]=="Dashboard metadata + position + UUID aliases" and not c["passed"] for c in report.checks)


def test_custom_display_code_is_emitted_in_all_contract_documents(artwork, tmp_path):
    output = build_package(replace(config(artwork, tmp_path), display_code="GV-006"))
    with zipfile.ZipFile(output) as z:
        for filename in ("level.json", "manifest.json", "package.json", "level-manifest.draft.json"):
            obj = json.loads(z.read(filename))
            assert obj["metadata"]["display_code"] == "GV-006"
            assert obj["display_code"] == "GV-006"
    assert validate_archive(str(output)).passed


def test_invalid_display_code_fails_before_export(artwork, tmp_path):
    with pytest.raises(ValueError, match="Display code"):
        build_package(replace(config(artwork, tmp_path), display_code="../../invalid"))
    assert not list((tmp_path / "exports").glob("*.zip"))


def test_missing_metadata_display_code_is_rejected_even_with_rehashed_package(artwork, tmp_path):
    from hashlib import sha256
    output = build_package(config(artwork, tmp_path))
    with zipfile.ZipFile(output) as source:
        data = {name: source.read(name) for name in source.namelist()}
    manifest = json.loads(data["manifest.json"])
    manifest["metadata"].pop("display_code")
    data["manifest.json"] = (json.dumps(manifest, ensure_ascii=False, sort_keys=True, indent=2)+"\n").encode()
    pkg = json.loads(data["package.json"])
    pkg["files"]["manifest.json"] = {"sha256": sha256(data["manifest.json"]).hexdigest(), "bytes":len(data["manifest.json"])}
    data["package.json"] = (json.dumps(pkg, ensure_ascii=False, sort_keys=True, indent=2)+"\n").encode()
    tampered = tmp_path / "missing-display-code.zip"
    with zipfile.ZipFile(tampered, "w") as target:
        for name, contents in data.items(): target.writestr(name, contents)
    report = validate_archive(str(tampered))
    assert not report.passed
    assert any(c["name"] == "Dashboard metadata + position + UUID aliases" and not c["passed"] for c in report.checks)


def test_explicit_position_overrides_level_suffix(artwork, tmp_path):
    """Display order can differ from stage number, but every manifest must agree."""
    generated = build_package(replace(config(artwork, tmp_path), position=12))
    with zipfile.ZipFile(generated) as z:
        for filename in ("level.json", "manifest.json", "package.json", "level-manifest.draft.json"):
            data = json.loads(z.read(filename))
            assert data["metadata"]["position"] == 12
            assert data["position"] == 12
    assert validate_archive(str(generated)).passed


@pytest.mark.parametrize("position", [0, -1, 1000001, True, "six", 1.5])
def test_invalid_position_rejected_before_export(artwork, tmp_path, position):
    with pytest.raises(ValueError, match="Position"):
        build_package(replace(config(artwork, tmp_path), position=position))
    assert not list((tmp_path / "exports").glob("*.zip"))


@pytest.mark.parametrize("bad_position", [None, "6", 0, True, 7])
def test_archive_position_missing_wrong_type_or_mismatch_is_rejected_even_if_rehashed(artwork, tmp_path, bad_position):
    """A self-consistent checksum cannot bypass a required metadata semantic field."""
    from hashlib import sha256
    output = build_package(config(artwork, tmp_path))
    with zipfile.ZipFile(output) as z:
        contents = {name:z.read(name) for name in z.namelist()}
    dashboard = json.loads(contents["manifest.json"])
    if bad_position is None:
        dashboard["metadata"].pop("position")
    else:
        dashboard["metadata"]["position"] = bad_position
    contents["manifest.json"] = (json.dumps(dashboard, sort_keys=True, ensure_ascii=False, indent=2)+"\n").encode()
    pkg = json.loads(contents["package.json"])
    pkg["files"]["manifest.json"] = {"sha256":sha256(contents["manifest.json"]).hexdigest(),
                                    "bytes":len(contents["manifest.json"])}
    contents["package.json"] = (json.dumps(pkg, sort_keys=True, ensure_ascii=False, indent=2)+"\n").encode()
    bad = tmp_path / "tampered-position.zip"
    with zipfile.ZipFile(bad,"w") as z:
        for name,blob in contents.items():
            z.writestr(name,blob)
    qa=validate_archive(str(bad))
    assert not qa.passed
    assert any(c["name"] == "Dashboard metadata + position + UUID aliases" and not c["passed"] for c in qa.checks)


def test_auto_position_tracks_level_number(artwork, tmp_path):
    output = build_package(replace(config(artwork, tmp_path), level_id="2-17"))
    with zipfile.ZipFile(output) as z:
        doc=json.loads(z.read("manifest.json"))
        assert doc["metadata"]["position"] == doc["position"] == 17
    assert validate_archive(str(output)).passed


# v1.0.7 — regression tests for the exact observed dashboard error
@pytest.mark.parametrize("count", [16, 36, 64, 100])
def test_dashboard_piece_count_present_in_both_metadata_views(artwork, tmp_path, count):
    out = build_package(config(artwork, tmp_path, count))
    with zipfile.ZipFile(out) as z:
        level = json.loads(z.read("level.json"))
        files = z.namelist()
        for name in ("level.json", "manifest.json", "package.json", "level-manifest.draft.json"):
            payload = json.loads(z.read(name))
            assert payload["metadata"]["piece_count"] == count
            assert type(payload["metadata"]["piece_count"]) is int
            assert payload["piece_count"] == count
            assert payload["grid_rows"] * payload["grid_cols"] == count
            assert payload["image_path"] == payload["metadata"]["image_path"]
        assert len(level["pieces"]) == count
        assert len([p for p in files if p.startswith("pieces/")]) == count
        assert len([p for p in files if p.startswith("masks/")]) == count
    qa = validate_archive(str(out))
    assert qa.passed, qa.as_dict()


def _mutate_indexed_json_payload(src_path, out_path, filename, mutator):
    from hashlib import sha256
    with zipfile.ZipFile(src_path) as z:
        data = {name: z.read(name) for name in z.namelist()}
    payload = json.loads(data[filename]); mutator(payload)
    data[filename] = (json.dumps(payload, sort_keys=True, ensure_ascii=False, indent=2) + "\n").encode()
    checks = json.loads(data["checksums.json"])
    checks[filename] = {"sha256": sha256(data[filename]).hexdigest(), "bytes":len(data[filename])}
    data["checksums.json"] = (json.dumps(checks, sort_keys=True, ensure_ascii=False, indent=2) + "\n").encode()
    pkg = json.loads(data["package.json"])
    pkg["files"][filename] = {"sha256": sha256(data[filename]).hexdigest(), "bytes":len(data[filename])}
    pkg["files"]["checksums.json"] = {"sha256": sha256(data["checksums.json"]).hexdigest(), "bytes":len(data["checksums.json"])}
    data["package.json"] = (json.dumps(pkg, sort_keys=True, ensure_ascii=False, indent=2) + "\n").encode()
    with zipfile.ZipFile(out_path, "w", compression=zipfile.ZIP_DEFLATED) as z:
        for name, content in data.items(): z.writestr(name, content)


@pytest.mark.parametrize("bad_value", [None, "100", True, 99, 0])
def test_rejects_bad_root_piece_count_even_if_archive_rehashed(artwork, tmp_path, bad_value):
    original = build_package(config(artwork, tmp_path))
    tampered = tmp_path / "broken-root-count.zip"
    def change(payload):
        if bad_value is None:
            payload.pop("piece_count")
        else:
            payload["piece_count"] = bad_value
    _mutate_indexed_json_payload(original, tampered, "manifest.json", change)
    result = validate_archive(str(tampered))
    assert not result.passed
    assert any(x["name"] == "Dashboard root + nested piece_count and physical tile count" and not x["passed"] for x in result.checks)


@pytest.mark.parametrize("bad_value", [None, "16", True, 36, -1])
def test_rejects_bad_nested_piece_count_even_if_archive_rehashed(artwork, tmp_path, bad_value):
    original = build_package(config(artwork, tmp_path))
    tampered = tmp_path / "broken-nested-count.zip"
    def change(payload):
        if bad_value is None:
            payload["metadata"].pop("piece_count")
        else:
            payload["metadata"]["piece_count"] = bad_value
    _mutate_indexed_json_payload(original, tampered, "manifest.json", change)
    result = validate_archive(str(tampered))
    assert not result.passed
    assert any(x["name"] == "Dashboard root + nested piece_count and physical tile count" and not x["passed"] for x in result.checks)


@pytest.mark.parametrize("count", [16,36,64,100])
def test_dashboard_level_time_limit_aliases_and_full_optional_context(artwork, tmp_path, count):
    cfg = config(artwork, tmp_path, count,
                 total_seconds=1800, three_star_seconds=900, two_star_seconds=1440,
                 prerequisite_level_id="1-5")
    path = build_package(cfg)
    with zipfile.ZipFile(path) as z:
        jsons = [json.loads(z.read(name)) for name in (
            "level.json", "level-manifest.draft.json", "manifest.json", "package.json")]
        for doc in jsons:
            assert doc["level_time_limit_seconds"] == doc["metadata"]["level_time_limit_seconds"] == 1800
            assert doc["three_star_elapsed_max_seconds"] == doc["metadata"]["three_star_elapsed_max_seconds"] == 900
            assert doc["two_star_elapsed_max_seconds"] == doc["metadata"]["two_star_elapsed_max_seconds"] == 1440
            assert doc["prerequisite_level_id"] == "1-5"
            assert doc["image_width"] == doc["image_height"] == 512
        assert validate_archive(str(path)).passed


@pytest.mark.parametrize("field,invalid", [("level_time_limit_seconds",None),
                                            ("level_time_limit_seconds",0),
                                            ("level_time_limit_seconds",False),
                                            ("level_time_limit_seconds",1800.0),
                                            ("level_time_limit_seconds",6000),
                                            ("three_star_elapsed_max_seconds",1700)])
def test_time_contract_fails_closed_when_modified_even_if_hashes_recomputed(artwork,tmp_path,field,invalid):
    from hashlib import sha256
    built = build_package(config(artwork,tmp_path,
        total_seconds=1800,three_star_seconds=900,two_star_seconds=1440))
    # Replace metadata with invalid value in all 4 docs to prove that even a
    # consistent falsified count cannot pass the independent timer contract.
    with zipfile.ZipFile(built) as z:
        contents={n:z.read(n) for n in z.namelist()}
    for file in ("level.json","level-manifest.draft.json","manifest.json","package.json"):
        doc=json.loads(contents[file]);doc[field]=invalid;doc["metadata"][field]=invalid
        contents[file]=(json.dumps(doc,sort_keys=True,indent=2,ensure_ascii=False)+"\n").encode()
    # Recompute relevant integrity indices to rule out a checksum-only failure.
    files=["level.json","level-manifest.draft.json"]
    dash=json.loads(contents["manifest.json"])
    for name in files:
        info={"sha256":sha256(contents[name]).hexdigest(),"bytes":len(contents[name])}
        dash["assets"][name]=dash["files"][name]=info
    contents["manifest.json"]=(json.dumps(dash,sort_keys=True,indent=2,ensure_ascii=False)+"\n").encode()
    checks=json.loads(contents["checksums.json"])
    for name in ("level.json","level-manifest.draft.json","manifest.json"):
        checks[name]={"sha256":sha256(contents[name]).hexdigest(),"bytes":len(contents[name])}
    contents["checksums.json"]=(json.dumps(checks,sort_keys=True,indent=2,ensure_ascii=False)+"\n").encode()
    pkg=json.loads(contents["package.json"])
    for name in ("level.json","level-manifest.draft.json","manifest.json","checksums.json"):
        pkg["files"][name]={"sha256":sha256(contents[name]).hexdigest(),"bytes":len(contents[name])}
    contents["package.json"]=(json.dumps(pkg,sort_keys=True,indent=2,ensure_ascii=False)+"\n").encode()
    out=tmp_path/"modified-time.zip"
    with zipfile.ZipFile(out,"w",compression=zipfile.ZIP_DEFLATED) as z:
        for name,data in contents.items():z.writestr(name,data)
    report=validate_archive(str(out))
    assert not report.passed
    assert any(item["name"] == "Dashboard time-limit metadata + timer parity" and not item["passed"] for item in report.checks), report.as_dict()
