# 08 — Security, quality gates and public repository audit

## Critical repo finding (26 Nov 2026)
The **public** GitHub repository currently tracks generated MariaDB/MySQL data files inside \`PuzzleQuest_Code/.tools/mysql-test/\`, including \`ibdata1\`, \`ib_logfile0\`, \`ib_logfile1\`, system database tables and PID/log files. These should NOT normally be in a public source repository. We have **not** verified whether the contents include real user data or secrets. Treat as potential exposure until reviewed.

Actions for an authorized security cleanup: (a) audit tracked files and image archives for credentials/PII, (b) move runtime data and dumps out of Git, (c) update ignore rules, (d) evaluate history rewrite and secret rotation if sensitive content actually leaked. Never assume \`.gitignore\` removes a previously tracked file. Do not delete files or rewrite public Git history casually.

## Protect these materials
- Production \`.env\`/APP_KEY, OAuth secrets, Studio bearer token, service-account keys, Ed25519 private signing key, player DB/exports, session tokens, passwords, phone/email data.
- Exclude backups, storage private files, logs, .tools test DB data, executable binaries/tool caches and ZIP/ RAR containing hidden runtime data from release/commit as appropriate.
- Public assets should contain only approved game images, vetted SVG with no scripts/external references, CSS/JS, and no PHP secrets.
- \`public_html\` must only hold the subdomain site, not Laravel private code; preserve main site.

## Gameplay integrity
- Backend owns authentication, level unlock/replay, attempt timing, stars, ledger, currency and reward claims.
- Idempotency key/atomic transaction on money/reward mutation; SSV signed and replay-resistant, rate limit abusive requests.
- Guest merge: single wallet, no duplicate first-win bonus and preserved best progress.
- Studio token scoped/revocable/short-lived, HTTPS-only; never stored in ZIP or logged.
- Level/art publishing immutable and signed/revisioned; all URLs and checksums refer to same revision.

## Content ZIP Quality Gate
- 960×960 true PNG master, exact grid for piece count 16/36/64/100.
- Every piece id/index/grid unique, paths safe and present, SVG masks restricted to safe elements.
- Positive/negative interlocking edges reciprocal, borders flat, no holes or duplicates, accurate alpha/image geometry and colors.
- ZIP traversal/symlink/bomb protection, entry/size bounds, SHA-256 all binaries; server revalidates regardless of Python success.
- Negative tests for missing metadata/world, duplicate piece hash, corrupt mask, invalid rows/cols, stale revision, upload timeout retry.

## Release acceptance matrix
| Gate | Local | Staging | Production |
|---|---|---|---|
| PHP lint + API route list + tests | must run | repeat | health check |
| Python unit tests + 16/36/64/100 export | must run | upload server | content published & fetched |
| Flutter analyze/test and Android/iOS device | must run | verify | player journey |
| Fresh Setup ZIP /install + DB migrations/seed | build ≠ test | **required** | only after staging |
| Update ZIP from supported version + migration | build ≠ test | **required for updates** | only after staging |
| Backup restore and data preservation | simulation ≠ proof | **required** | drill |
| Security and signatures / checksum / ZIP safety | required | required | required |
| UI/AR/EN real screens | goldens & test | required | regression |

Current root commit of the documentation can intentionally skip CI as owner requested, **but must not be described as having passed CI**.

## Relevant evidence in repo
- \`PuzzleQuest_Code/docs/RELEASE_ACCEPTANCE.md\`
- \`PuzzleQuest_Code/Game/RELEASE_BLOCKERS_AR.md\`
- \`PuzzleQuest_Code/backend/TEST_RESULTS.json\`
- \`PuzzleQuest_Code/PuzzleQuest_Studio/tests/\`
- \`PuzzleQuest_Code/backend/tests/\`

## Recovery in production
Before any release: tested backup of DB + files, encrypted PQB requires original APP_KEY, ensure access to safe recovery path. A failed irreversible migration cannot always be rolled back. See \`PuzzleQuest_Code/backend/RECOVERY_GUIDE_AR.md\`.
