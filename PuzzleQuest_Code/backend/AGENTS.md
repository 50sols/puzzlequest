# Worker notes — Laravel Backend (PuzzleQuest)

Read root \`AGENTS.md\` and docs/01_ARCHITECTURE_AR.md, docs/03_STUDIO_AND_CONTENT_AR.md, docs/04_CPANEL_RELEASE_AR.md, docs/08_SECURITY_QUALITY_AR.md **before** changing this app.

## Authority and important files
- \`routes/api.php\` player + remote studio routes; \`routes/web.php\` admin, pairing, health.
- \`app/Services/{Game,Content,StudioDocuments,Wallet,Rewards,Updates,Backups,Installer,ContentAssetRelocator}.php\`.
- \`bootstrap/app.php\` selects \`public_html/puzzlequest.50sols.com\` when app lives in \`/home/solscool/puzzlequest_app\`.
- \`database/migrations\`, \`database/seeders\`: preserve data and publish contract.
- \`app/Http/Controllers/StudioApiController.php\` + \`StudioPairingController.php\`, \`Http/Middleware/StudioToken.php\`.

## Never break
- Laravel owns account, unlock/replay, stars/timer/ledger, SSV and transactional rewards.
- Level \`Content::validate\` contract includes root level.json, manifest.json, 960 PNG, correct ids/world FK/AR-EN titles, exact N pieces/masks and safe SVG/ZIP.
- Content public files live in the **subdomain Document Root**; no shadow \`puzzlequest_app/public/content\`.
- Admin token is revocable and scoped, secrets are not stored in release ZIP.
- Fresh install next: build one complete Setup ZIP with web wizard + production vendor + frontend assets; do not install composer/npm/artisan on production for owner.
- Future updates: trusted Ed25519 and SHA256, strict from_version/layout, verified backup + safe migration/recovery. Never overwrite .env or uploads.
- Maintain cPanel \`cpanel_fixed_subdomain_v1\`. Never touch primary domain \`public_html/index.php\`.

## Test requirements (developer machine)
PHP lint, Laravel route/tests, MySQL/SQLite feature tests, Content PNG/SVG/ZIP checks with GD, installer fresh install on clean DB using actual ZIP, backup recovery and update when applicable. If dependencies are unavailable record NOT RUN; do not claim production-ready.

Owner currently does **not** want workflows invoked. Never automatically install Laravel Boost/Composer plugins or change PHP versions as a bootstrap side effect; use existing dependencies and only change them when explicitly required for the task.
