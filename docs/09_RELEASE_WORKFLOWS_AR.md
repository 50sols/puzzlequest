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
- في كل Push على فرع الإصلاح: يجري **Validate Laravel patch and ZIP contract** (Composer وPHP lint وLaravel tests) ثم تجربة توقيع بمفتاح اختبار مؤقت محلي داخل Runner، تُتحقق فيها سلامة ZIP والـManifest وSHA-256؛ يُتلف المفتاح والحزمة التجريبية ولا يُنشَر منهما شيء.
- إصدار الحزمة الحقيقية يتم **فقط عند تشغيل workflow_dispatch يدويًا**، وبعد نجاح الاختبارات، في Job مستقل `Publish trusted v1.0.1 Admin ZIP` يستخدم مفاتيح Release المستقرة من GitHub Actions Secrets وبيئة `release-signing`؛ ويمكن اشتراط موافقة المسؤول من إعدادات Environment.
- الحزمة المنشورة بعد نجاح Job التوقيع تتوافق مع `App\Services\Updates::verify()`: `release.json` (Manifest) + `release.sig` (توقيع Ed25519 موثوق) + `payload/...` (ملفات محددة وقيم SHA-256).
- **يلزم GitHub Actions Secrets:**
  - `PUZZLEQUEST_UPDATE_SIGNING_KEY_B64`: مفتاح توقيع Ed25519 خاص، 32-byte seed أو 64-byte libsodium secret، مشفر Base64.
  - `PUZZLEQUEST_UPDATE_PUBLIC_KEY_B64`: المفتاح العام المقابل، 32 bytes Base64، **نفس المفتاح العام الموثوق والمسجل في لوحة الإدارة** (`release_public_key`).
- مفتاح اختبار عشوائي مؤقت يُستخدم فقط للتحقق من آلية بناء ZIP داخل Runner، ويُحذف دون نشر الحزمة. لا يتم توليد مفتاح نشر موثوق تلقائيًا ولا وضع المفتاح الخاص في Git أو Artifact. إذا كانت مفاتيح الإصدار غير مهيأة، يظل **Job النشر اليدوي** محجوبًا بخطأ صريح؛ أما Push العادي فيتحقق من المصدر دون إنتاج حزمة قابلة للتركيب.
- يتم تثبيت التحديث **من اللوحة نفسها**: Settings → System → System Updates → Upload → Verify → Backup → Install → Health. يمنع فك ZIP مباشرة على cPanel أو استخدام Setup ZIP فوق الموقع المثبت.
- **إعداد المفتاح لأول مرة دون تعديل السيرفر:** GitHub Repository → Settings → Secrets and variables → Actions، احفظ مفتاح Ed25519 الخاص بصفة `PUZZLEQUEST_UPDATE_SIGNING_KEY_B64` والعام بصفة `PUZZLEQUEST_UPDATE_PUBLIC_KEY_B64` (أو أضفهما إلى Environment باسم `release-signing`). من PuzzleQuest Admin → الإعدادات / Hosting عيّن حقل مفتاح التحديث العام لنفس المفتاح العام. لا تشارك المفتاح الخاص عبر Chat أو ملفات Release.
- إذا كانت مفاتيح سابقة موثوقة بالفعل، يجب استخدام **نفس الزوج**؛ لا تستبدله عشوائيًا حتى لا تُرفض التحديثات الموقعة، ولا تُعد النسخة جاهزة للتثبيت قبل اختبار Upgrade على staging.


## شروط قبول حقيقية
1. نجاح اختبارات PHP وFlutter على commit الإصدار نفسه؛ تطابق SHA في `BUILD_INFO.json` وGitHub Run.
2. التحقق من أن مفتاح Public الموثوق بالموقع يطابق Build Info، وأن `SHA256SUMS.txt` وتوقيع `release.sig` صحيحان.
3. تجربة Upgrade من v1.0.0 على نسخة staging مع بيانات محفوظة واختبار الاسترجاع قبل الإنتاج؛ لا تعني `build success` الموافقة على النشر.
4. بعد نشر التحديث على الاستضافة، يُختبر HTTPS الفعلي لـ`master.png` و`manifest.json` وكل صور `16_pieces` من المرحلة 1-1 وSHA-256، ثم يفتح اللاعب المرحلة في APK التجريبي.
5. لا يوجد نشر تلقائي إلى الاستضافة أو أي تعديل على بيانات الإنتاج بواسطة هذين الـWorkflows.
