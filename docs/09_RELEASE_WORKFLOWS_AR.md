# 09 — PuzzleQuest: ورَكفلو تحديث Laravel وملف APK التجريبي

تم التصريح صراحةً بإنشاء هذين الـWorkflows بتاريخ 26 نوفمبر 2026، استثناءً محدودًا من سياسة عدم تشغيل CI أثناء التطوير.

## 1) تجربة Android — QA APK
**ملف:** `.github/workflows/puzzlequest-qa-apk.yml`  
**اسم Actions:** `PuzzleQuest | QA APK`  
**الناتج:** `PuzzleQuest-QA-<git-sha12>.apk` + `SHA256SUMS.txt` + `BUILD_INFO.json` ضمن Artifact `PuzzleQuest-QA-APK`.

- يعمل تلقائيًا عند push لفرع `fix/level-content-download-cpanel-20261126`، ويمكن تشغيله يدويًا من GitHub Actions بعد وصول ملف Workflow إلى default branch.
- يستعمل Flutter 3.47.6، Java 17، Android SDK، ويشغّل فحص تكامل السورس وDOC03 و`flutter analyze` و`flutter test`.
- يُنتج APK بنمط release للأداء لكنه **موقّع بتوقيع Android debug مؤقت**، **غير صالح للمتجر**. `applicationId=com.puzzlequest50sols.com.qa` حتى لا يستبدل تطبيق الإنتاج أو تقدمه.
- يولّد إعداد Firebase مؤقتًا **للبناء التجريبي فقط**، وPush معطل. Google Sign-In/FCM غير معتمدين في هذه النسخة. AdMob يستخدم App ID تجريبي موجود في الـManifest.
- اختبار اللعبة الكامل يتطلب نشر إصلاح Laravel بالتحديث الصحيح أولًا أو استخدام بيئة Staging مكافئة. نجاح البناء لا يثبت أن السيرفر المباشر يعيد ملفات المرحلة بنجاح.

## 2) تحديث لوحة Laravel — Admin ZIP
**ملف:** `.github/workflows/puzzlequest-admin-update.yml`  
**اسم Actions:** `PuzzleQuest | Signed Admin ZIP Update`  
**الناتج:** `PuzzleQuest-Update-v1.0.1.zip` + `RELEASE_NOTES.md` + `BUILD_INFO.json` + `SHA256SUMS.txt` ضمن Artifact `PuzzleQuest-Admin-Update-v1.0.1`.

- التحديث المسموح: `from_version=1.0.0` إلى `version=1.0.1` وبنية `cpanel_fixed_subdomain_v1` فقط.
- Payload المحدد في `PuzzleQuest_Code/backend/release/update-files.json`: إصلاح API للصور + خدمة كتالوج اللعبة + Routes + تعريف الإصدار، دون تغيير DB أو dependencies أو الملفات المنشورة.
- يعمل فحص Composer وPHP lint واختبارات Laravel، ثم يبني ZIP ببنية يفهمها `App\Services\Updates::verify()`:
  `release.json` (Manifest) + `release.sig` (توقيع Ed25519 حقيقي) + `payload/...` (ملفات محددة وقيم SHA-256).
- **يلزم GitHub Actions Secrets:**
  - `PUZZLEQUEST_UPDATE_SIGNING_KEY_B64`: مفتاح توقيع Ed25519 خاص، 32-byte seed أو 64-byte libsodium secret، مشفر Base64.
  - `PUZZLEQUEST_UPDATE_PUBLIC_KEY_B64`: المفتاح العام المقابل، 32 bytes Base64، **نفس المفتاح العام الموثوق والمسجل في لوحة الإدارة** (`release_public_key`).
- لا يتم توليد مفتاح خاص مؤقت، ولا إنتاج تحديث غير موقّع، ولا وضع المفتاح الخاص في Git أو Artifact. إذا كانت المفاتيح غير مهيأة يفشل Workflow عمدًا ولا يعطي ZIP مضللًا.
- يتم تثبيت التحديث **من اللوحة نفسها**: Settings → System → System Updates → Upload → Verify → Backup → Install → Health. يمنع فك ZIP مباشرة على cPanel أو استخدام Setup ZIP فوق الموقع المثبت.

## شروط قبول حقيقية
1. نجاح اختبارات PHP وFlutter على commit الإصدار نفسه؛ تطابق SHA في `BUILD_INFO.json` وGitHub Run.
2. التحقق من أن مفتاح Public الموثوق بالموقع يطابق Build Info، وأن `SHA256SUMS.txt` وتوقيع `release.sig` صحيحان.
3. تجربة Upgrade من v1.0.0 على نسخة staging مع بيانات محفوظة واختبار الاسترجاع قبل الإنتاج؛ لا تعني `build success` الموافقة على النشر.
4. بعد نشر التحديث على الاستضافة، يُختبر HTTPS الفعلي لـ`master.png` و`manifest.json` وكل صور `16_pieces` من المرحلة 1-1 وSHA-256، ثم يفتح اللاعب المرحلة في APK التجريبي.
5. لا يوجد نشر تلقائي إلى الاستضافة أو أي تعديل على بيانات الإنتاج بواسطة هذين الـWorkflows.
