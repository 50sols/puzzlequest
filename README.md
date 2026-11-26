# PuzzleQuest — خريطة المشروع / Worker Entry Point

**ابدأ بـ [AGENTS.md](AGENTS.md) قبل أي تعديل.** هذا المستودع يشمل اللعبة والـBackend وبرنامج Python وتصاميم اللعبة وخططها. تم تدقيق المسارات على الشجرة الفعلية في 26 نوفمبر 2026. وجود ميزة في المصدر لا يعني أنها متاحة على الخادم أو مجتازة لاختبار الإنتاج.

## مكان كل جزء

| Component | Code path | Why it exists |
|---|---|---|
| 🎮 Game | [PuzzleQuest_Code/Game/](PuzzleQuest_Code/Game/) | Flutter + Flame; شاشات اللاعب ومحرك البازل والقرية |
| 🖥️ Server | [PuzzleQuest_Code/backend/](PuzzleQuest_Code/backend/) | Laravel, MariaDB, Admin, API, rewards, signed installs/updates |
| 🧩 Studio | [PuzzleQuest_Code/PuzzleQuest_Studio/](PuzzleQuest_Code/PuzzleQuest_Studio/) | Windows Python app: image→jigsaw ZIP, online content admin |
| 🎨 Design | [PuzzleQuest_Design_FINAL/](PuzzleQuest_Design_FINAL/) | 40 player screens, 13 admin sections, design tokens, artwork, handoff |
| 📦 Original delivery | [cPanel_Setup/](cPanel_Setup/) | Older setup reference—not an instruction to overwrite a live installation |

## Worker Handbook (read in this order)
1. [01 — Architecture and dependencies](docs/01_ARCHITECTURE_AR.md)
2. [02 — Game, progression and economy](docs/02_GAMEPLAY_AR.md)
3. [03 — Python Studio, remote API, content ZIP](docs/03_STUDIO_AND_CONTENT_AR.md)
4. [04 — cPanel fixed-subdomain, first install, releases and recovery](docs/04_CPANEL_RELEASE_AR.md)
5. [05 — Design map and visual rules](docs/05_DESIGN_MAP_AR.md)
6. [06 — Roadmap and open delivery gates](docs/06_ROADMAP_AR.md)
7. [07 — Worker execution and handoff](docs/07_WORKER_PLAYBOOK_AR.md)
8. [08 — Security, QA and existing repo risks](docs/08_SECURITY_QUALITY_AR.md)

## Deployment baseline
The **next delivery requested by the owner is a clean first installation**, not an upgrade of any currently running site. Never infer production version or contents from an archived ZIP. Use the fixed cPanel layout:
- Private Laravel: \`/home/solscool/puzzlequest_app\`
- Subdomain document root: \`/home/solscool/public_html/puzzlequest.50sols.com\`
- App endpoint: \`https://puzzlequest.50sols.com/\`
- Clean setup: ONE ZIP → browser \`/install/\` → live game + admin; no composer/npm/artisan from the end user on production.
- All following releases: signed, verified Admin ZIP Updates with backups, migrations and health gates.

## Rules
- Laravel is authoritative for wallets, stars, unlocks, time and rewards. Flutter and Python do not mint rewards.
- A published puzzle revision is immutable; Draft → validate → preview/device QA → approve → publish. Changing art creates a **new revision**.
- Do not trigger GitHub Actions / workflows now. Local checks are allowed; report exactly what ran.
- Public repository: no credentials, player data, .env, signing private keys or database files in new commits.
- Keep existing APIs and player progression intact until a contracted migration is accepted.
