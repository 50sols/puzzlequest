# 06 — Roadmap: work lanes, milestones and unresolved gates

**Status labels:** Implemented in source ≠ Local tests passed ≠ Staging passed ≠ Production verified. This file is a working map, not a release certification.

## Priority P0 — new clean baseline
1. Freeze reviewed source for Game + Laravel + Python and manifest contracts; source SHA & version consistency.
2. Build **fresh cPanel Setup ZIP** with production Composer vendor, public subdomain assets and working /install wizard; install on clean MySQL/cPanel-like staging, confirm .env/key/seed/admin/lock.
3. Test public asset path \`public_html/puzzlequest.50sols.com/content\`, file checksums and public URL.
4. Execute real restore rehearsal from encrypted backup; retain original APP_KEY securely.
5. Create release artifacts with same commit provenance; do NOT call a build alone production-ready.
6. **Owner decision: no GitHub Actions/workflows triggered now**. Note pending CI as an open release gate.

## P1 — core game path
- End-to-end Flutter guest/auth + Google provider verification.
- First 5 Green Valley levels + any added sixth: correct canonical IDs, order, content revisions, unlocking, **replay completed levels**.
- 960×960 jigsaw with 16/36/64/100 pieces, truly reciprocal tabs, transparent PNG/SVG, drag/snap alpha hit zones, no seams at multiple resolutions.
- Correct active revision download, SHA-256 and cache behavior, retry/offline resume.
- Timers, pause/background, star thresholds, 1st-win reward idempotency, timeout.
- QA on Android and iOS; UI AR/EN, accessibility, input and 40-screen parity.

## P2 — Studio creator + connected Admin
- One ZIP image→pieces→masks→JSON Quality Gate; generate revision UUID, unique IDs, filenames and correct world DB ID.
- Upload to server, \`ready\` revision, explicit device QA, Publish, keep old published immutable; live image URLs.
- Author worlds, levels, level groups, collections, banners, art, events, story and village visuals through scoped Studio token with revoke/expiry.
- Handle 100-piece upload timeouts by querying revisions before retry; server requests bounded/observable.
- Add authenticated preflight that checks all required \`level.json\` / \`manifest.json\` fields at once with useful errors; do not reveal secrets.
- Keep event definitions separate from verified calendar/reward execution logic.

## P3 — village, collections and engagement
- Client actually renders Studio village scenes in correct layer/z with L0..L4, synced to server-owned building stage. Never pay upgrades from visual CMS.
- Collections/badges/trophies and reward chest eligibility, one-time claim.
- Daily/weekly missions, event scheduling, inbox and quiet-hour/timezone policy, push/FCM/APNs.
- AdMob rewarded SSV & interstitial frequency/consent enforcement.
- Robust player account merge, privacy erase/export and fraud/abuse tests.

## P4 — design and maintainability
- Match 40 player screens and 13 admin sections with intended artwork, reusable widgets, goldens and error/empty states.
- Device/performance budget (memory, game size, jigsaw 100 pieces, cache hit, request latency).
- CI: when owner later authorizes workflows, run Flutter analyzer/test/build, Python tests, PHP tests, source checks, *actual* Setup fresh install and Update upgrade, backup preservation/recovery tests.

## Known concrete source blockers at documentation time
- \`Game/RELEASE_BLOCKERS_AR.md\` flags missing Android/iOS build and physical-device QA for \`v1.2.0+5\`, image-seam/hitmask tests and service integrations.
- \`PuzzleQuest_Code/docs/RELEASE_ACCEPTANCE.md\` records missing end-to-end MySQL/cPanel install/upgrade/recovery and Flutter Studio CMS rendering verification.
- \`backend/BUILD_INFO.json\` still labels historical v1.0.2 even though code contains later Studio/public-path changes. Reconcile release metadata **before** publishing a new baseline.
- Public Git tracks .tools/mysql-test test database files and other large generated artifacts; security and history clean-up requires separate authorized procedure.
- Previous integration reported game complete states while replay tap only worked on first level; QA regression required on Flutter authenticated session.
- Latest published server state must not be inferred from an uploaded archive or admin screenshot from an earlier deployment; new task is **fresh install**.

## Prioritization rule
Work on verifiable runnable vertical slices, not a stack of speculative design documents. Close a feature only when API, client, data, error states and real QA evidence align. Don't block normal development by dispatching workflows against owner's direction.
