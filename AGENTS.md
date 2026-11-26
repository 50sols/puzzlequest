# PuzzleQuest — instructions for all coding workers

## Read before coding
- \`README.md\` and all \`docs/01_...08_...\` worker handbook files.
- Nearest component docs: \`Game/README_AR.md\`, \`PuzzleQuest_Studio/README_AR.md\`, \`backend/WORKER_GUIDE_AR.md\`.
- Design authorities: \`PuzzleQuest_Design_FINAL/03_HANDOFF/OWNER_DECISIONS_AR.md\`, \`02_DESIGN/DESIGN_TOKENS.json\`, \`Game/docs/DOC03_DESIGN_TO_DEVELOPMENT_AR.md\`.
- For backend API and asset formats, **read source**, not old handoff: \`backend/app/Services/Content.php\`, \`Game.php\`, \`Updates.php\`, \`backend/routes/api.php\`, \`PuzzleQuest_Code/docs/REMOTE_API_CONTRACT.md\`.

## Work boundaries
- Game: \`PuzzleQuest_Code/Game\` — Flutter/Flame and shipped player experiences.
- Backend: \`PuzzleQuest_Code/backend\` — server authority, admin, API, persistence, content import, installer and release.
- Studio: \`PuzzleQuest_Code/PuzzleQuest_Studio\` — image manipulation and remote desktop content manager.
- Design: \`PuzzleQuest_Design_FINAL\` — reference assets, screens, product decisions; not proof of implemented behavior.
- A change spanning components must update all touched contracts and tests. Do not silently change JSON field names, piece paths or release semantics.

## Mandatory product and security invariants
1. Keep coins, hints, unlocks, best stars, wallet ledger, AdMob SSV and rewards **server-authoritative**; retries must be idempotent.
2. Publishing: Draft → validation/QA → Approved → Published immutable content revision; active play remains pinned to old revision. Never rewrite published art in place.
3. Puzzle ZIP: \`level.json\` and \`manifest.json\` in ZIP root; \`master.png\` 960×960; \`{N}_pieces/piece_000.png\`; \`{N}_masks_svg/piece_000.svg\` with reciprocal edge geometry. Validate from source \`Content::validate\`.
4. \`world_id\` DB ID uses \`green_valley\`, not \`green-valley\`. \`display_code\` e.g. \`1-6\`; \`level_id\` e.g. \`level_006_green_valley\`.
5. Shared hosting: \`cpanel_fixed_subdomain_v1\`, private backend at \`/home/solscool/puzzlequest_app\`, public web root at \`/home/solscool/public_html/puzzlequest.50sols.com\`. Never deploy PHP private files into public_html or save uploaded puzzle assets into \`puzzlequest_app/public/content\`.
6. **Next server delivery is a first-time Setup ZIP.** Do not assume old production state; never run an old update ZIP as new setup or overwrite a site already installed.
7. Clean setup includes vendor, compiled assets and browser installer; subsequent update ZIPs need Ed25519 trusted signatures, SHA-256, version constraints, backup and recovery plan.
8. No production server commands required from user. If cPanel requires DB creation or Document Root change, explain that explicitly.
9. Never commit real .env, keys, MariaDB data dir, DB dumps, user uploads or tokens. Repo is currently PUBLIC and needs a tracked-file security review.
10. Do not start/dispatch/configure GitHub Actions at this time; owner prioritizes development speed. Do not claim green CI.
11. Distinguish **designed**, **implemented in source**, **locally tested**, **staging tested**, **production verified** in handoffs; do not claim missing evidence.
12. Do not modify Android/iOS signing or native configurations unless required by the user's specific game task.

## Delivery procedure
Inspect main HEAD → isolate relevant files → implement focused change → run available local tests → report blocked tests → document config/migrations/data compatibility → commit with clear scope and SHA. Do not merge an unverified production release. Keep the source, Setup and Update artifacts traceable to the tested commit.

### Worker handoff template
- Scope + authoritative user decision
- Starting branch/commit and edited paths
- API/DB/asset changes; migrations/backward compatibility
- Commands and results **actually run**
- Files/artifacts with SHA-256 and availability
- Outstanding gates, rollback/recovery and next concrete action
