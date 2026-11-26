# 05 — Design source map and implementation standards

## Where to find real artwork
\`PuzzleQuest_Design_FINAL/00_SHARED/\`:
- \`art/backgrounds\`, \`art/buildings\`, \`art/characters\`, \`art/puzzle_scenes\`, \`art/rewards\`, \`art/worlds\`: approved/proposed illustrations (check license and approval).
- \`puzzles/level_001\` to \`level_005_...\`: source puzzle references, not automatically playable binaries.
- \`ui/buttons\`, \`ui/inputs\`, \`ui/gameplay\`, \`ui/panels\`, \`ui/progress\`, \`ui/states\`, \`ui/tutorial\`, \`icons/svg\` and \`icons/png\`: component sources/states.
- \`branding\`, \`fonts\`, \`audio\`: branding/typography and audio references, verify licenses and that **runtime font binaries** exist.

## Canonical design documents
- \`PuzzleQuest_Design_FINAL/02_DESIGN/DESIGN_TOKENS.json\`: baseline design variables.
- \`PuzzleQuest_Design_FINAL/03_HANDOFF/OWNER_DECISIONS_AR.md\`: owner-locked decisions.
- \`PuzzleQuest_Design_FINAL/03_HANDOFF/BACKEND_DEVELOPMENT_PLAN_AR.md\`, \`OPEN_QUESTIONS_AR.md\`, \`VALIDATION.json\`: planned backend and pending gaps.
- \`PuzzleQuest_Code/Game/docs/DOC03_DESIGN_TO_DEVELOPMENT_AR.md\`: Flutter component integration and behavior, compare to source widgets and true screenshots.

## Player screen map (all 40 directories exist)
| Group | Screens |
|---|---|
| Entry and identity | 01 Splash; 18 Welcome; 19 Sign In; 20 Register; 21 OTP; 22 Forgot; 23 Reset; 24 Guest; 25 Avatar |
| Main play | 02 Village; 03 Worlds; 04 Levels; 05 Preview; 06 Gameplay; 07 Complete; 31 Tutorial |
| Assistance/reward | 13 Full Image Rewarded; 14 Hint Options; 15 Pause; 16 Reward Chest; 17 Image After Rewarded; 33 Daily Rewards |
| Growth/competition | 08 Missions/Events; 09 Collections; 10 Leaderboard; 11 Shop; 32 Village Upgrade; 34 Achievements |
| Account/support | 12 Profile/Settings; 26 My Account; 27 Edit; 28 Privacy; 29 Guest Progress; 30 Delete Confirmation; 35 Inbox; 36 Help |
| Failure and privacy | 37 Connection Recovery; 38 Ad Unavailable; 39 Loading/Empty/Error; 40 Privacy Consent |

Check \`PuzzleQuest_Design_FINAL/01_SCREENS/{number}_{name}/\` for actual screens and revisions. Do not infer that screen directory == finished Flutter screen.

## 13 dashboard design groups
\`PuzzleQuest_Design_FINAL/04_BACKEND_DESIGN/\` contains 01 Admin Overview; 02 Worlds/Levels; 03 Level Details; 04 Shop/Economy; 05 Daily Rewards; 06 Players/Progress; 07 Village; 08 Activities/Collection; 09 Ads; 10 Account/Privacy/Support; 11 Updates; 12 Push/Scheduling; 13 System Settings. Real route is \`/admin/module/{number}\`; never confuse design screen filenames with Laravel controller routing.

## UI rules
- Arabic + English localization, RTL-aware layout, bidi isolation for numbers/IDs and email.
- Use design token colors and provided button states rather than re-drawing generic controls.
- Responsive 320/390/600 preview/golden candidates; safe areas, accessibility large text, hover/pressed/disabled/error/loading states.
- Reuse \`lib/widgets/component_library.dart\` and \`lib/core/theme.dart\` while verifying design parity.
- Reduced motion, haptics, sound preferences; never animate without accessibility guard.
- Font decision conflict in old docs (Lato vs Nunito); **follow current owner decisions and verified design tokens** until formal change; Tajawal for Arabic.
- Screenshots/art references don't establish completed interaction; manual tests necessary.

## Asset workflow
Design → approved source → adapted for game constraints → export → SHA/naming manifest → developer wiring → previews (AR/EN sizes) → real-device QA → publish. Never strip licensing or treat preview-only placeholders as approved.
