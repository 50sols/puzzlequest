# PuzzleQuest Game v1.2.0+5 — Developer source changelog

- Baseline: Full source 1.1.1 recovery + Gradle Hotfix 1.1.2 + Kotlin 2.3 Hotfix 1.1.3 + Resource Shrink Hotfix 1.1.4.
- Theme tokens: replaced provisional semantic colors with exact approved `DESIGN_TOKENS.json` source, copied the original token/interaction contracts and 20 button-state PNG assets.
- 20-component DOC03 interface registry with explicit state enums, server-authoritative wallet/result semantics, accessibility labels, idempotent async CTA, developer-only asset/component preview.
- Integrated component views into live worlds, levels, missions, shop, daily rewards, results, achievements, profile settings, inbox and gameplay HUD.
- Preferences: reduced motion, haptic, system click audio independently persisted; no change to scoring, entitlement, or economy.
- Puzzle tray: UI state is `selected` separately from true `nearSlot` geometry, so selection no longer masquerades as a near-target hint.
- Native preparation: preserve all 3 pinned Android compatibility files after regenerating Flutter runners.
- Unit/widget tests and source validation added; 1.2.0 runtime/build gates remain open until tested on Mac.
