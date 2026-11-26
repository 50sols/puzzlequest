# 03 — Python Studio + level ZIP + direct server management

## Windows Studio
Path: \`PuzzleQuest_Code/PuzzleQuest_Studio/\`. Run on developer machine with \`launch_windows.bat\` (after Python+venv dependencies). GUI combines local puzzle builder, Quality Gate and Remote Online Manager. Python only sends HTTPS requests; **Laravel selects storage locations**.

## Make a new level
1. Choose approved artwork (PNG/JPG/WebP), validate license/ownership and crop to square.
2. Choose \`world_id\` from server (for Green Valley **\`green_valley\`**), \`level_id\` unique lowercase/underscore (e.g. \`level_006_green_valley\`), \`display_code\` (e.g. \`1-6\`), integer \`position\` and AR/EN title.
3. Choose 16,36,64,100 pieces, time and two star thresholds; new UUID for every content revision.
4. Generate 960×960 master PNG, interlocking PNG pieces, safe SVG masks, exact grid anchors and reciprocal edges.
5. Run **local Quality Gate** for missing pieces, masks, duplicate textures, core coverage, geometry, identifiers, SHA-256 and safe ZIP paths. Fail closed.
6. Import package to server; Laravel runs **its own** authoritative \`Content::validate\` (not just client QA); store Revision \`ready\`.
7. Preview on actual Flutter devices (16/36/64/100, RTL and scaling), explicit Device QA, then Publish immutable revision. Never overwrite already published assets.

### ZIP structure (canonical)
\`\`\`text
PuzzleQuest-Level.zip
  level.json            # required server metadata
  manifest.json         # schema_version 1.0.0
  master.png            # PNG 960x960
  36_pieces/piece_000.png ... piece_035.png
  36_masks_svg/piece_000.svg ... piece_035.svg
\`\`\`
Folder prefix is \`16_\`, \`36_\`, \`64_\`, or \`100_\` based on \`piece_count\`, not a hardcoded \`36_\`.

### Minimum level.json (server expects nine required fields)
\`\`\`json
{
  "level_id":"level_006_green_valley",
  "world_id":"green_valley",
  "display_code":"1-6",
  "position":6,
  "title":{"ar":"الوادي الأخضر — المستوى السادس","en":"Green Valley — Level Six"},
  "piece_count":100,
  "level_time_limit_seconds":1800,
  "three_star_seconds":900,
  "two_star_seconds":1440,
  "previous_level_id":"level_005_autumn_tree"
}
\`\`\`
No assumption that example values are correct for an arbitrary new level. World must exist in DB.

### Manifest invariants
\`schema_version:"1.0.0"\`, \`level_id\` equals metadata, \`difficulty_piece_count\` equals metadata/count pieces, \`grid.rows\` and \`grid.columns\` square root of count, \`board_size_px:[960,960]\`, \`master_image_path:"master.png"\`, \`snap_threshold_board_px>0\` and <= half cell, \`padding_px\` integer, \`cell_size_px\` (960/grid), \`piece_ordering:"row_major"\`. Each piece has \`id:piece_000\`, \`index\`, \`row\`, \`column\`, PNG \`image_path\`, SVG \`mask_path\`, \`target_rect_px:[col*cell-padding,row*cell-padding,cell+2*padding,cell+2*padding]\`, \`snap_anchor_px:[col*cell,row*cell]\` and \`edges:{top,right,bottom,left}\` with 0 outer edges, reciprocal ±1 internal edges. Backend validator is source-of-truth.

## Online Manager
- One-time pairing via Laravel owner page \`/admin/studio\`; Studio token has 7-day lifetime, revocable, **never** saved with project settings.
- API \`/api/studio/v1\`, requests with \`Authorization: Bearer <token>\`; endpoints and permissions: \`PuzzleQuest_Code/docs/REMOTE_API_CONTRACT.md\`.
- CRUD: \`worlds\`, \`levels\`, \`revisions\`; Draft documents \`collection\`, \`level_group\`, \`world_art\`, \`village_scene\`, \`village_item\`, \`event\`, \`mission\`, \`achievement\`, \`banner\`, \`story\`; Upload image media; publish/retire/history/restore to draft.
- Village editor: background image UUID, objects with x/y 0..1, scale 0.1..4, z -100..100, building_id and stage 0..4; **publishing art is not upgrading player's building**.
- Events and missions as CMS **definitions** do not automatically activate economic rewards or gameplay logic.

## Failure handling
- A Python upload timeout does NOT establish that server import failed; query Revisions first before retrying (immutable content might exist).
- Generic 'Invalid level identity' check: existing \`world_id\` and AR/EN title, uniqueness, correct display code and level ID.
- Wrong public path fixed in Laravel via \`bootstrap/app.php\` binding, not by changing Python output path.
- If the player can see completion but cannot replay, compare authenticated \`/catalog\` + \`/attempts\` and Flutter tap conditions; never wipe progress to mask a UI bug.

## Testing contract
Python generation tests, Laravel real \`Content::validate\` with GD, ZIP slip/bomb/symlink rejection, upload API auth/rate limit, publish QA flag, client content SHA, 960×960 full piece placement, device replay. Incomplete integration must be reported as such.
