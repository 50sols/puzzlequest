# Worker notes — Flutter/Flame Game

Read root \`AGENTS.md\` and docs/02_GAMEPLAY_AR.md, docs/05_DESIGN_MAP_AR.md, docs/08_SECURITY_QUALITY_AR.md. Source: \`lib/main.dart\`, \`lib/core/{api,content,models,theme}.dart\`, \`lib/game/\`, \`lib/screens/\`, \`lib/widgets/\`; design: \`PuzzleQuest_Design_FINAL\` and \`docs/DOC03_DESIGN_TO_DEVELOPMENT_AR.md\`.

- Backend is source of truth for unlock, best stars, coins/hints and rewards. Completed levels must **remain replayable**.
- Use approved native design assets/tokens, no visual shortcuts to generic placeholders. Validate AR/EN and RTL.
- Never invent URL paths or mutate immutable asset revision; validate SHA and manifest geometry before gameplay.
- Test time/pause/resume, device touch hit/drag/snap on 16/36/64/100 pieces, clean seam, mobile layout, offline cache, all 40 screen flows.
- Existing \`RELEASE_BLOCKERS_AR.md\` states the v1.2.0+5 mobile build/device acceptance has not been verified; don't claim production ready.
- Do not trigger workflows. Do not regenerate Android/iOS signing configs or share release credentials.
