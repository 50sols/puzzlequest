# PuzzleQuest Studio / Laravel v1.1.0 — release acceptance gate

- [x] Source inspected from the user's `PuzzleQuest_Code(1).rar`.
- [x] New routes register with Laravel, PHP `php -l` syntax checks.
- [x] Python remote-client security tests and inherited builder/QA tests.
- [x] Signed Ed25519 Update ZIP (`release.json`+`release.sig`), file SHA-256 and strict version bounds.
- [x] Setup ZIP rebuild includes production `vendor` dependency tree and browser installer (not independently installed).
- [ ] **Unverified**: PHP DB feature suite with MySQL/SQLite and required PHP extensions.
- [ ] **Unverified**: clean browser installation from setup ZIP on cPanel.
- [ ] **Unverified**: signed upgrade from actual installed server version and backups/recovery.
- [ ] **Unverified**: authenticated Studio token + upload + publish integration against the production server.
- [ ] **Unverified**: Flutter/Flame consumes and displays village scenes, collections and scheduled events (Flutter sources were not in upload).
- [ ] **Unverified**: production release CI on final Git commit (uploaded source RAR has no `.git`).

No production-ready/GA claim until unchecked items are independently verified.
