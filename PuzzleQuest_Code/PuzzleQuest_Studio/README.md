# PuzzleQuest Studio v1.1.2 — Exact asset manifest format

The default Laravel exporter now creates `manifest.json`, `level.json`, `master.png`, `<N>_pieces/piece_000.png`, `<N>_masks_svg/piece_000.svg`. For 36 pieces, cell_size_px=160, padding_px=44, snap_threshold_board_px=35 and row_major numbering. `level.json` stays mandatory for the production importer even though it may not be visible in examples of already-published content. Exported ZIPs are independently verified before release. This fixes *local output format*, not server file placement. Do not overwrite a published revision: import as a new revision with device QA approval.

# PuzzleQuest Studio v1.0.9 — Laravel Content.php contract

This release adds a new default Laravel-compatible export path. It is grounded in the **actual owner-supplied** `app/Services/Content.php` and `app/Services/SafeZip.php` from `app.rar`, not guessed metadata aliases.

- Windows: double-click `launch_windows.bat` (Python and dependency bootstrap where possible).
- macOS: `launch_mac.command`.
- CLI: `python -m puzzlequest_studio.cli build --image artwork.png --pieces 100 --world EXACT_DB_WORLD_ID --level 1-6 --title 'Green Valley Watermill' --title-ar 'طاحونة الوادي الأخضر' --timer 1800 --three-star 900 --two-star 1440 --rights-confirmed`
- Verify: `python -m puzzlequest_studio.cli verify path/to/PuzzleQuest-Laravel-....zip`

## Authentic server contract

`level.json` requires root keys: `level_id`, `world_id`, `display_code`, `position`, `title` (`ar` + `en`), `piece_count`, `level_time_limit_seconds`, `three_star_seconds`, `two_star_seconds`. `level_id` is lowercase letters, digits, underscores only; `display_code` is digits-digits. World ID must already exist in database.

`manifest.json` requires `schema_version="1.0.0"`, `board_size_px=[960,960]`, `difficulty_piece_count`, `level_id`, `pieces` array, `grid.rows/columns`, `padding_px`, `snap_threshold_board_px`, `master_image_path` (960x960 PNG). Every piece needs row/column, snap anchors, target rect, PNG tile, safe SVG mask and reciprocal edges.

The ZIP importer accepts extensions JSON, PNG, JPG, JPEG, WebP, SVG only and enforces strict safe-archive and size rules.

**External gates not tested:** production `worlds.id` existence; server PHP GD and real import; remote storage, published level identity, resource limits; device QA and publication. The local revision UUID is distinct from server-issued content_revisions.id.

See `README_AR.md` and `docs/LARAVEL_CONTENT_IMPORT_CONTRACT.json`.
