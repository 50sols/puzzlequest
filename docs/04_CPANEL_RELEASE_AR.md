# 04 — cPanel: FIRST INSTALL baseline, release packages and recovery

## Owner decision (2026-11-26)
**Do not treat any historical server deployment as the base for the next handoff.** The next package is a **clean first-time Setup ZIP** built from the latest reviewed source and installed on a new/cleared target. No attempt to upgrade or reuse the previous production database is authorized by this instruction. Do not delete an old installation as a side effect.

## Fixed subdomain layout: cpanel_fixed_subdomain_v1
\`\`\`text
/home/solscool/
├── puzzlequest_app/                         # Laravel PRIVATE, not web-accessible
│   ├── app/ bootstrap/ config/ database/
│   ├── resources/ routes/ vendor/ storage/
│   ├── .env                                 # created at install; NEVER shipped
│   └── VERSION
└── public_html/
    ├── (existing main 50sols.com files — untouched)
    └── puzzlequest.50sols.com/              # subdomain DOCUMENT ROOT
        ├── index.php
        ├── .htaccess
        ├── install/
        ├── content/{level_id}/{revision}/
        └── fonts/...
\`\`\`
The \`bootstrap/app.php\` public path binding must point Laravel \`public_path()\` at this **specific subdomain** and never to \`puzzlequest_app/public\` or the main \`public_html\`. Source \`backend/app/Services/Content.php\` writes imported assets through \`public_path()\`. Validate public HTTP URLs and checksums after upload.

## Fresh install (one ZIP, no SSH on production)
1. Build a complete, **single** \`PuzzleQuest-Setup-vX.Y.Z.zip\` using final Git commit + production \`vendor\` + all compiled/public files + actual web installer. Never upload a developer source ZIP as a Setup.
2. In cPanel choose PHP with correct extensions (PDO MySQL, mbstring, sodium, GD, ZIP, DOM, OpenSSL etc). Verify ownership/permissions and subdomain Document Root.
3. In File Manager upload Setup ZIP at \`/home/solscool\` and **extract once there**, never at subdomain root or main \`public_html\`.
4. Configure an empty MySQL/MariaDB database and DB user in cPanel if host doesn't allow automatic database creation. Browser wizard \`https://puzzlequest.50sols.com/install/\`: preflight → DB test → secure .env/APP_KEY → migrations/seed → Super Admin → mail/queue/cache/storage → health → locked installation.
5. Verify public site/admin, SSL, API, DB, published level URLs, login, backup/restore, and missing modules. Do not mark production-ready without real evidence.
6. Preserve .env/APP_KEY separately in secure offline storage; do not place in Git or public packages. Installer must lock after completion.

## Future ZIP updates only after successful first install
- UI: Admin → System Updates; \`Verify\` → Backup → Maintenance → Apply → Migrations → Cache → Health → Finish.
- Manifest: Semantic Version, \`from_version\`, \`version\`, \`deployment_layout:cpanel_fixed_subdomain_v1\`, \`files\` SHA-256, compatibility, provenance and release notes. Detached Ed25519 signature verified with preconfigured trusted **public** key.
- Never commit or ship release **private signing key**. A checksum alone is not authenticity.
- Block downgrade, unsupported delta, file traversal/symlink/zip bomb, concurrent operations, secret overwrites. Preserve player DB, uploads, \`.env\`, APP_KEY, settings.
- Avoid assuming database migrations are reversible. Restore from verified backup only through a tested recovery procedure; if a migration is destructive, use forward-compatible deployment and explicit recovery.
- \`backend/app/Services/Updates.php\` and \`Backups.php\` are critical. Current source may vary from older public server versions; verify the **actual version and layout** before ever building an update ZIP.

## Rules for worker release delivery
- Do not dispatch GitHub Actions now. Local tests may run, but list manual/missing CI gates separately.
- Fresh Setup ZIP must be **exercised as a ZIP** on a clean DB/install environment; not just zipfile integrity.
- After setup, verify game API/public home/admin and asset URLs; test fake/real picture ZIP, rollback/restore and no user secrets exposed.
- A successful build/signature is *not* an accepted production release. Provide exact SHA-256 and evidence for passed and blocked checks.
- Do not recommend extracting Setup over an already installed site.
- Read original \`PuzzleQuest_Code/backend/DEPLOY_CPANEL_AR.md\`, \`RECOVERY_GUIDE_AR.md\`, \`tools_build_cpanel_setup.py\` for existing paths; note old version labels there are historical, not current deployment proof.

## Release artifact bookkeeping
\`\`\`text
dist/
  PuzzleQuest-Setup-vX.Y.Z.zip
  PuzzleQuest-Update-vX.Y.Z.zip        # only when supported from_version exists
  manifest.json
  release-notes.md
  build-info.json
  SHA256SUMS.txt
  acceptance-results.json
\`\`\`
Generate from ONE tested commit; Setup and Update must correspond to identical source.
