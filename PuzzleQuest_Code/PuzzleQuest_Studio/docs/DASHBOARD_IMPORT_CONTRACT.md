# PuzzleQuest Laravel importer — actual source contract (26 November 2026)

Authoritative input is the user's `app.rar` containing `app/Services/Content.php` and `app/Services/SafeZip.php`, especially `Content::validate()` and `Content::import()`.

The canonical machine-readable contract is [LARAVEL_CONTENT_IMPORT_CONTRACT.json](LARAVEL_CONTENT_IMPORT_CONTRACT.json).

## MUST BE IN `level.json` ROOT (not nested `metadata`)
`level_id`, `world_id`, `display_code`, `position`, `title` containing `ar` & `en`, `piece_count`, `level_time_limit_seconds`, `three_star_seconds`, `two_star_seconds`.

## `manifest.json` root fields
`schema_version` = `1.0.0`; `board_size_px` = `[960,960]`; `difficulty_piece_count` = meta count; `level_id` matching level.json; `grid` with `rows`, `columns`; integer `padding_px`; positive `snap_threshold_board_px`; `master_image_path` to actual 960x960 PNG; array `pieces` with IDs, positions, image PNG, SVG mask, snap anchor, target rectangle, reciprocal edges.

The server checks pixel-level correspondence to source image and full board coverage using PHP GD; local parity validation matches the documented algorithm but must be verified on production. ZIP is limited to 1500 entries and 128MiB uncompressed. Allowed extensions: JSON PNG JPG JPEG WEBP SVG.

**NOT VERIFIED:** live DB `worlds.id`, server PHP GD availability, real upload success, upload/storage permissions and device QA acceptance. Do not claim release ready from local tests alone.

The studio's own UUID is a build provenance ID; upon import Laravel generates a separate UUID for `content_revisions.id`.
