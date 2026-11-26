# 02 — Gameplay, progression, economy and content

## رحلة اللاعب
Splash/Welcome → Guest or Email/Google auth → Home / My Village → Worlds Map → Level List → Preview → Jigsaw Gameplay → Result / stars / coins → collections, badges, village upgrades. Other flows: daily reward, missions/events, shop, leaderboard, profile/security, notifications, support, empty/offline states. Canonical screen references: \`PuzzleQuest_Design_FINAL/01_SCREENS/01_...40_...\`.

## Worlds and levels
- Launch Green Valley originally comprised five levels: IDs \`green_valley_house_001\`, \`level_002_windmill_spring\`, \`level_003_snow_castle\`, \`level_004_sky_balloon\`, \`level_005_autumn_tree\`; corresponding piece counts **16, 16, 36, 64, 100**.
- A sixth level \`level_006_green_valley\` (display \`1-6\`, Green Valley, 100 pieces) was introduced in later content work; check database and active revision in deployment before saying it is live. \`world_id\` for this world is \`green_valley\`.
- New levels follow a predecessor link \`previous_level_id\`; \`Game::unlocked(uid, level)\` checks published world, published level, active revision, completed prior world(s), and predecessor with at least 1 star.
- **Completed level must remain replayable.** Three stars are not a lock. Regression: level 1-2..1-6 after database QA progress fixtures; verify actual Flutter click and API response, not only SQL.
- Catalogue and reward rules: source \`app/Services/Game.php\`, \`resources/product/APPROVED_PRODUCT_RULES.json\`, seeders and Game models. Do not hard-code changes from old screenshot or an answer.

## Timers & scoring
Historical launch QA handoff values:
| Level | Pieces | Total time | 3★ elapsed max | 2★ elapsed max |
|---|---:|---:|---:|---:|
| 1-1 | 16 | 360s | 150s | 270s |
| 1-2 | 16 | 360s | 150s | 270s |
| 1-3 | 36 | 600s | 270s | 450s |
| 1-4 | 64 | 1080s | 480s | 840s |
| 1-5 | 100 | 1800s | 900s | 1440s |

Treat as **owner/design baseline**; persisted current level metadata wins for actual play. No timer deduction while legitimately paused or app backgrounded. Timed preview/rewarded interactions require server verification and must not double-settle.

## Coins / hints / rewards
Initial guest wallet historically 300 coins + 2 hints; hint coin cost 100, shuffle 150, full-image preview 200 / 30 seconds; first win bonus 500 once per level, and rewarded preview/hint requires SSV. These come from project decisions and must be verified against current product config before changes. Financial/economy mutations must use idempotency keys, ledger and server policy. Never award currency from Studio metadata or Flutter local state.

## Village
- Visual \`village_scene\` uses a referenced background image and ordered objects: \`asset_id\`, \`x,y\` normalized 0..1, \`scale\`, \`z\`, \`building_id\`, \`stage\` 0..4. See \`docs/03_STUDIO_AND_CONTENT_AR.md\`.
- Distinguish **village artwork layout** (CMS) from **building upgrade balances/progression** (Game/Rewards/Wallet); CMS art must not silently upgrade players.
- Preserve L0 ruined to L4 upgraded visual variants and map correct stage to server-owned building state.

## Known QA and client integration
- Flutter \`lib/core/content.dart\` must verify immutable revision and SHA; \`puzzle_board.dart\` places alpha PNG pieces at manifest target rectangles. Verify 960x960 board-coordinate drag and snap at 320/390/600 widths, under RTL, offline and slow network.
- Published Studio CMS documents are included in API data, but client still needs explicit screen-level render/interaction. Do not claim a new event or village scene appears in game solely because Studio published it.
- QA: launch, unlock/replay, 16/36/64/100 geometry, 1/2/3 stars, timeout, partial restart, background pause, offline reconciliation, rewarded SSV, badge/reward chest one-time rules, guest merge, sign-in, store policy.

## Authoritative files
\`PuzzleQuest_Code/backend/app/Services/Game.php\`, \`Content.php\`, \`Wallet.php\`, \`Rewards.php\`; \`PuzzleQuest_Code/Game/lib/core/models.dart\` and \`content.dart\`; \`PuzzleQuest_Design_FINAL/03_HANDOFF/OWNER_DECISIONS_AR.md\`.
