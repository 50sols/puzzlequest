# PuzzleQuest — السورس الكامل المدمج (Game 1.2.0+5 / DOC 03)

هذا ملف **المشروع الكامل** بنفس هيكل `PuzzleQuest_Full_Source_Flutter_Flame_v1.1.0.zip` المشار إليه من مكتبتك.

تم الاحتفاظ بكل ملفات `PuzzleQuest_Code/backend` و`PuzzleQuest_Design_FINAL` و`cPanel_Setup` من الحزمة الأصلية دون تعديل، مع دمج كود وAssets وTests لعبة `Game v1.2.0+5` وتعديلات DOC03.

**تحديث مهم:** تمت إعادة الخطوط الخمسة الأصلية (Tajawal / Lato) من الأرشيف الأصلي. ملفات Game المُدمجة كاملة مع الأصول؛ لم تُستبدل الخطوط بملفات بديلة.

## ماذا يشمل؟

- `PuzzleQuest_Code/Game/`: Flutter + Flame ومكتبة المكونات DOC 03؛ آخر إصلاحات Android Gradle وKotlin.
- `PuzzleQuest_Code/backend/`: Laravel backend/source + اختبارات ومكونات التثبيت، كما في الحزمة الأصلية.
- `PuzzleQuest_Design_FINAL/`: أصول ومواصفات التصميم الأصلية.
- `cPanel_Setup/PuzzleQuest-Setup-v1.0.2-cPanel-Subdomain.zip`: حزمة تثبيت Backend السابقة، وليست تحديثًا للخادم الجاري.
- `PuzzleQuest_Code/Game/docs/DOC03_DESIGN_TO_DEVELOPMENT_AR.md`: مرجع مكتبة المكونات والمطابقة.

## تحديث المشروع الحالي على Mac دون فقد ملفات Native المُنشأة

```bash
cd ~/Desktop
unzip -o ~/Downloads/PuzzleQuest_Full_Source_Backend_Design_Game_DOC03_v1.2.0_MERGED.zip -d .
cd PuzzleQuest_Design_Handoff_Updated/PuzzleQuest_Code/Game
python3 tool/check_source_integrity.py
python3 tool/verify_doc03.py
flutter pub get
flutter analyze
flutter test
flutter run -d emulator-5554
```

فك ZIP يضيف/يستبدل الملفات ولا يحذف ملفات `android/ios` التي ولّدها Flutter على الماك. لا تنفذ `flutter create` فوق المشروع بعد استخدام هذا الأرشيف إلا إذا احتجت فعلًا توليد ملفات المنصات؛ راجع `Game/README_AR.md`.

## حالة التحقق

نجح التحقق من سلامة السورس والـDOC03 والأصول والملفات في بيئة التجميع، لكن لم يتوفر Flutter SDK هنا لبناء نسخة اللعبة 1.2.0 ولا لاختبارها على Android/iOS. نجاح تشغيل الإصدار الأقدم على محاكيك لا يثبت تشغيل الإصدار الجديد. **هذه حزمة سورس وليست إصدار متجر أو تحديث للخادم الحي.**

تفاصيل المصدر: `PuzzleQuest_Code/Game/MERGE_SOURCE_INFO.json`، نتائج QA: `PuzzleQuest_Code/Game/QA_REPORT.json` و `RELEASE_BLOCKERS_AR.md`.
