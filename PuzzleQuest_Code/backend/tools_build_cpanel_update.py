#!/usr/bin/env python3
"""Build the signed Admin ZIP Update accepted by app/Services/Updates.php.

Never ship a private signing key or a live server file. This is intentionally
limited to an explicit reviewed file allowlist and a single supported upgrade.
"""
from __future__ import annotations

import argparse
import base64
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import re
import stat
import zipfile

from nacl.signing import SigningKey, VerifyKey

ROOT = Path(__file__).resolve().parent
SPEC = ROOT / "release" / "update-files.json"
ALLOWED = re.compile(
    r"^(?:app/|bootstrap/(?!cache/)|config/|database/migrations/|"
    r"resources/|routes/|vendor/|public/(?!install/)|artisan$|composer\.(?:json|lock)$)"
)
VERSION = re.compile(r"^[0-9]+\.[0-9]+\.[0-9]+$")
SHA = re.compile(r"^[0-9a-f]{40}$")
PROTECTED = re.compile(r"(^|/)(?:\.env(?:\..*)?|storage|install\.key)(?:/|$)", re.I)


def safe_file(relative: str) -> Path:
    if not relative or "\\" in relative or not re.fullmatch(r"[A-Za-z0-9_./-]+", relative):
        raise ValueError(f"Unsafe payload name: {relative!r}")
    posix = PurePosixPath(relative)
    if (posix.is_absolute() or any(part in ("", ".", "..") for part in relative.split("/"))
            or not ALLOWED.match(relative) or PROTECTED.search(relative)):
        raise ValueError(f"Protected update target: {relative!r}")
    root = ROOT.resolve()
    file = ROOT / relative
    if any(part.is_symlink() for part in [file, *file.parents] if part != root and root in part.parents):
        raise ValueError(f"Symlink in source path: {relative}")
    resolved = file.resolve(strict=True)
    if root not in resolved.parents or not resolved.is_file():
        raise ValueError(f"Invalid update source file: {relative}")
    return resolved


def decode_b64(name: str) -> bytes:
    text = os.environ.get(name, "").strip()
    if not text:
        raise ValueError(f"{name} is required; refusing to publish an unsigned ZIP")
    try:
        return base64.b64decode(text, validate=True)
    except (ValueError, base64.binascii.Error) as exc:
        raise ValueError(f"{name} is not valid base64") from exc


def build(output: Path) -> Path:
    spec = json.loads(SPEC.read_text(encoding="utf-8"))
    old = spec["from_version"]
    new = spec["version"]
    if not VERSION.fullmatch(old) or not VERSION.fullmatch(new):
        raise ValueError("Invalid semantic version")
    if tuple(map(int, new.split("."))) <= tuple(map(int, old.split("."))):
        raise ValueError("Target version must be greater than installed version")
    if spec["deployment_layout"] != "cpanel_fixed_subdomain_v1":
        raise ValueError("Unsupported deployment layout")
    files = spec["files"]
    if not isinstance(files, list) or not files or len(set(files)) != len(files):
        raise ValueError("File allowlist is empty or has duplicate members")
    if "config/puzzlequest.php" not in files:
        raise ValueError("Include version-bearing config/puzzlequest.php")
    version_config = (ROOT / "config" / "puzzlequest.php").read_text(encoding="utf-8")
    if not re.search(r"'version'\s*=>\s*'" + re.escape(new) + r"'", version_config):
        raise ValueError("Source config version differs from signed target version")

    key = decode_b64("PUZZLEQUEST_UPDATE_SIGNING_KEY_B64")
    public = decode_b64("PUZZLEQUEST_UPDATE_PUBLIC_KEY_B64")
    if len(key) not in (32, 64) or len(public) != 32:
        raise ValueError("Ed25519 private key must be 32-byte seed or 64-byte libsodium secret; public key must be 32 bytes")
    signer = SigningKey(key[:32])
    if bytes(signer.verify_key) != public:
        raise ValueError("Release private/public key mismatch: not trusted by target admin")
    git_sha = os.environ.get("GITHUB_SHA", "")
    if not SHA.fullmatch(git_sha):
        raise ValueError("Build requires an exact Git SHA from GitHub Actions")

    names = {}
    checksums = {}
    for name in sorted(files):
        content = safe_file(name).read_bytes()
        if len(content) > 20 * 1024 * 1024:
            raise ValueError(f"Update file too large: {name}")
        names["payload/" + name] = content
        checksums[name] = hashlib.sha256(content).hexdigest()

    notes_path = ROOT / "release" / ("RELEASE_NOTES_" + new + ".md")
    notes = notes_path.read_text(encoding="utf-8")
    manifest = {
        "product": "PuzzleQuest",
        "schema_version": 1,
        "deployment_layout": spec["deployment_layout"],
        "version": new,
        "from_version": old,
        "min_supported_version": old,
        "php_min": spec["php_min"],
        "git_sha": git_sha,
        "dependencies": {"composer": "unchanged", "frontend_assets": "unchanged"},
        "migrations": [],
        "release_notes": notes,
        "files": checksums,
        "built_at_utc": datetime.now(timezone.utc).isoformat(),
    }
    signed_bytes = (json.dumps(manifest, ensure_ascii=False,
                               sort_keys=True, separators=(",", ":")) + "\n").encode("utf-8")
    signature = signer.sign(signed_bytes).signature
    VerifyKey(public).verify(signed_bytes, signature)
    names["release.json"] = signed_bytes
    names["release.sig"] = base64.b64encode(signature) + b"\n"

    output.mkdir(parents=True, exist_ok=True)
    target = output / ("PuzzleQuest-Update-v" + new + ".zip")
    with zipfile.ZipFile(target, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=7) as archive:
        for name, body in sorted(names.items()):
            item = zipfile.ZipInfo(name)
            item.create_system = 3
            item.external_attr = (stat.S_IFREG | 0o644) << 16
            item.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(item, body, compress_type=zipfile.ZIP_DEFLATED, compresslevel=7)
    with zipfile.ZipFile(target, "r") as archive:
        assert archive.testzip() is None, "Bad ZIP member CRC"
        assert set(archive.namelist()) == set(names), "Unknown or missing release file"
        assert archive.read("release.json") == signed_bytes
        VerifyKey(public).verify(archive.read("release.json"),
                                 base64.b64decode(archive.read("release.sig").strip(), validate=True))
        for file, digest in checksums.items():
            assert hashlib.sha256(archive.read("payload/" + file)).hexdigest() == digest

    notes_out = output / "RELEASE_NOTES.md"
    notes_out.write_text(notes, encoding="utf-8")
    build_info = output / "BUILD_INFO.json"
    build_info.write_text(json.dumps({
        "product": "PuzzleQuest",
        "from_version": old,
        "version": new,
        "git_sha": git_sha,
        "artifact": target.name,
        "update_zip_sha256": hashlib.sha256(target.read_bytes()).hexdigest(),
        "payload_sha256": checksums,
        "signature_algorithm": "Ed25519",
        "public_key_b64": base64.b64encode(public).decode(),
        "verification": "ZIP CRC, manifest signature and all payload SHA-256 validated",
        "production_verified": False,
        "staging_upgrade_verified": False,
    }, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    sums = output / "SHA256SUMS.txt"
    sums.write_text("".join(
        hashlib.sha256(item.read_bytes()).hexdigest() + "  " + item.name + "\n"
        for item in (target, notes_out, build_info)
    ), encoding="utf-8")
    print("Signed, byte-verified update:", target)
    print("Upgrade:", old, "->", new, "SHA:", git_sha)
    print("This package is not production-certified without a staging upgrade test.")
    return target


if __name__ == "__main__":
    parser = argparse.ArgumentParser()
    parser.add_argument("--out", type=Path, default=ROOT / "dist")
    args = parser.parse_args()
    build(args.out.resolve())
