# Worker notes — Python Windows Studio

Read root \`AGENTS.md\`, docs/03_STUDIO_AND_CONTENT_AR.md, docs/08_SECURITY_QUALITY_AR.md. Source: \`puzzlequest_studio/{gui,builder,geometry,quality,laravel_import,remote,online_manager,village_editor}.py\`. Main entry \`launch.py\`.

- Generate canonical root \`level.json\` + \`manifest.json\`, \`master.png\`, \`{N}_pieces/piece_000.png\`, \`{N}_masks_svg/piece_000.svg\` (N=16/36/64/100).
- Use \`world_id\` from API, not label; Green Valley is \`green_valley\`. Keep \`level_id\` slug distinct from \`display_code\`.
- Quality Gate rejects missing/invalid masks, duplicate pieces, edge/rect geometry mismatch, unsafe ZIP and out-of-bounds images. Do not bypass it.
- Revision must be immutable; upload timeout is ambiguous, query revisions before retry.
- Python uploads over HTTPS but does **not** choose server filesystem location; server Laravel \`public_path()\` must point to cPanel subdomain root.
- Remote token stays in memory, is revocable and must never appear in logs, ZIP, repo or default config.
- Village art placement ≠ player upgrade. CMS event text ≠ automatic economy actions.
- Python tests should be run locally; no workflow dispatch without new owner instruction.
