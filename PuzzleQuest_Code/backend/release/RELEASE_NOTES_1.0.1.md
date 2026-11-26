# PuzzleQuest v1.0.1 — Public puzzle content delivery hotfix

Supported upgrade: **v1.0.0 → v1.0.1**, fixed cPanel subdomain layout only.

- Published revision assets are served through a checksum-pinned HTTPS Laravel API.
- Protects immutable content: only files in the published revision's SHA-256 allowlist can be downloaded.
- Keeps all existing puzzle revisions, player progress, wallets, content uploads, and private .env unchanged.
- No schema migrations, Composer dependency updates, or frontend compiled-asset changes.

## Install via Admin → Settings → System Updates
Upload the signed `PuzzleQuest-Update-v1.0.1.zip`; Verify → Backup → Install → Health check.
The trusted Ed25519 **public** key configured in Admin must match the CI release signing key.
Never extract the update ZIP in cPanel, never run Setup ZIP over the live site.

## Acceptance before production
Run PHP / Flutter tests, verify the v1.0.0 fresh-install and v1.0.1 upgrade on staging,
confirm real published 1-1 `master.png`, `manifest.json` and 16 piece PNG URLs return 200
and their checksums match; launch puzzle 1-1 on a device. Packaging alone does not certify production.
