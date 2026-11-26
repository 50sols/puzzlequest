# 07 — Worker Playbook: how to contribute without conflict

## Before any change
1. Read root \`AGENTS.md\` and these docs, then component instructions.
2. Verify current git \`main\` HEAD, branch leases and changed files; do not assume a previously cited SHA remains current.
3. Read targeted runtime source, current tests, owner decisions and matching artwork. List plan for cross-component change.
4. Never treat older ZIPs, SQL dumps, setup docs or design-only fields as production behavior.

## Workstream routing
| Work type | Main location | Must coordinate |
|---|---|---|
| Jigsaw geometry | Python \`geometry.py\`, \`laravel_import.py\` | Backend \`Content.php\`, Flutter models/content |
| Player screen/Replay | Game \`lib/screens\`, \`lib/core\` | Backend Game catalog/start; QA progress fixtures |
| Economy or scores | Backend \`Game.php\`, \`Wallet.php\`, \`Rewards.php\` | DB migrations/ledger + Flutter UI |
| New world/level | Python Online Manager + Backend StudioApi | player API, artwork, mobile renderer |
| Village art placement | Python \`village_editor.py\` | StudioDocuments, media API, Flutter village screen |
| Auth/SSV/push | Laravel middleware/controllers | client token safety, anti-replay, legal & provider tests |
| cPanel install/release | Backend Installer/Updates/Backups + packaging | layout and signing, recovery and real DB evidence |
| Design parity | Design tokens & screens | Flutter components, AR/EN/accessibility |

## Branch/commit workflow
- Use short topic branch, focused code and tests. Describe exactly which components and files change.
- Review backwards-compatible JSON/DB contract; add version bump and migration if needed.
- Run local tests that are available; if Flutter/PHP/MySQL not installed, say \`NOT RUN\` with blocker.
- Owner currently says **NO GitHub workflows**. Do not call Actions/dispatch, edit workflow configuration, or assume skipped CI is passed.
- Small docs can be committed without release; code affecting production should not auto-deploy. No unrequested credential or database mutation.
- PR/merge only after policy and required tests/approvals where applicable. Human production deployment remains a separate action.

## Acceptance checklist
- Functional flow demonstrated using same input/output contract as real app.
- Negative tests for missing schema keys, content ZIP corruption, traversal, authorization, replay, timeout, idempotency.
- Arabic/English UX and accessibility, visual validation on actual screens/devices.
- Migration safe and re-runnable; data/settings/APP_KEY/uploads preserved when upgrading.
- Release Setup/Update ZIP actually tested and signed (when relevant); SHA-256 recorded.
- No secrets or data dump in commit or final build; security review especially for tracked artifacts.

## Handoff template to paste into issues/PRs
\`\`\`markdown
### Change
- Goal, owner decision, scope and components:
- Base commit / head commit:
- Changed files + behavior:
### Contracts
- API/JSON schema, migrations, compatibility:
- Data integrity and auth boundaries:
### Evidence
- Commands/tests actually run and results:
- Build/Setup/Update SHA256 (when applicable):
- Screenshots/device/DB evidence:
- Missing CI or environment checks (explicit):
### Risks / recovery
- Known blockers and recovery plan:
- Next exact action + owner-facing preview:
\`\`\`
