# 01 — معمارية PuzzleQuest والعلاقات

## 1. الغرض
PuzzleQuest لعبة Jigsaw 2D مبنية بـFlutter/Flame، مع Backend Laravel وMariaDB ولوحة Admin، وبرنامج Python Studio محلي على Windows لإنشاء مستويات البازل وإدارة المحتوى مباشرة عن طريق HTTPS. التصميم محفوظ مستقلًا في \`PuzzleQuest_Design_FINAL\`.

\`\`\`text
Design references / artwork
           │
           ├──> Python Studio (Windows)
           │       ├─ image + 16/36/64/100 pieces → validated ZIP
           │       └─ Studio Bearer Token → /api/studio/v1/
           │                                      │
           ▼                                      ▼
Flutter/Flame Game <-- player API /api/v1/ -- Laravel + MariaDB + Admin
  content downloads <---- public/content/          │
                                                 cPanel /admin
                                         Published immutable revision
\`\`\`

## 2. Source tree (confirmed)
- \`PuzzleQuest_Code/Game/lib/main.dart\`: game entry; \`lib/core/api.dart\`: HTTP; \`lib/core/content.dart\`: downloading/checking assets; \`lib/core/models.dart\`: typed contracts; \`lib/game/gameplay.dart\` / \`puzzle_board.dart\`: Flame board; \`lib/screens/screens.dart\`: screens; \`lib/widgets/\`: reusable UI.
- \`PuzzleQuest_Code/backend/routes/api.php\`: player + Studio API; \`routes/web.php\`: admin/health/Studio pairing; \`app/Services/Game.php\`: progression and catalog; \`Content.php\`: level ZIP validator/import and publish; \`Wallet.php\` / \`Rewards.php\`: economy; \`Updates.php\`, \`Backups.php\`, \`Installer.php\`: release.
- \`PuzzleQuest_Code/backend/app/Http/Controllers/StudioApiController.php\`: remote operations; \`StudioPairingController.php\`: admin token pairing; \`app/Services/StudioDocuments.php\`: Draft/revisions/document types; \`ContentAssetRelocator.php\`: legacy assets.
- \`PuzzleQuest_Code/PuzzleQuest_Studio/puzzlequest_studio/\`: \`gui.py\`, \`builder.py\`, \`geometry.py\`, \`quality.py\`, \`laravel_import.py\`, \`remote.py\`, \`online_manager.py\`, \`village_editor.py\`; entry \`launch.py\`.
- \`PuzzleQuest_Design_FINAL\`: screen art, tokens, specs, planned content. Reference only; real behavior must be verified in running app.

## 3. Trust boundaries
- Flutter displays authenticated/verified server state, never directly mutates DB or accepts local reward authority.
- Python may generate PNG/SVG/JSON and upload with a revocable, short-lived Studio API token. Server verifies data, identity, authorization and geometry again.
- \`/admin/studio\` pairs a desktop token after protected owner reauthentication. Password is **never** stored in the Python client.
- Public \`/api/v1/studio-content\` returns **published** documents only, filtered by publication state/world/time; the client must implement rendering for visible UI.

## 4. Three content planes
1. **Gameplay plane:** canonical worlds/levels, attempts, progress, stars, wallets, daily rewards and quests; state is authoritative in Laravel.
2. **Immutable puzzle revision plane:** \`content_revisions\`, \`manifest.json\`, master PNG, pieces, masks; published revision referenced by level; no destructive update.
3. **CMS/visual plane:** Studio documents (\`collection\`, \`level_group\`, \`world_art\`, \`village_scene\`, \`village_item\`, \`event\`, \`mission\`, \`achievement\`, \`banner\`, \`story\`) with Draft→Publish and image media library. Defining events doesn't automatically create wallet reward logic.

## 5. Operational paths
- Player API: \`https://puzzlequest.50sols.com/api/v1/\`
- Studio API: \`https://puzzlequest.50sols.com/api/studio/v1/\`
- Admin: \`/admin\`, Studio pairing: \`/admin/studio\`, health \`/health\`.
- Fresh installer: \`/install/\` on new deployment only.
- public puzzle content: \`/content/{level_id}/{immutable_revision}/...\`.

## 6. Change map
Game UI change → check designs and Flutter tests. Puzzle data change → Python generator + Laravel \`Content::validate\` + Flutter manifest parser + fixture tests. Economy change → Laravel invariants + ledger/replay tests and Flutter loading/error states. Deployment change → cPanel layout + signed release + fresh-install/backup/recovery gates.

## 7. Reality vs plan
This document records current source and intended contracts, not proof of functioning on a given production installation. Read \`docs/06_ROADMAP_AR.md\` for evidence gates.
