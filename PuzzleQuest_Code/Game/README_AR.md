# PuzzleQuest — Game Source v1.2.0+5

**المسار الصحيح:** `PuzzleQuest_Code/Game/`، سورس Flutter/Flame الخاص باللعبة. المرجعية `PuzzleQuest_Design_FINAL`، وبالأخص `02_DESIGN/DESIGN_TOKENS.json` ووثيقة DOC 03 المؤرخة 25 نوفمبر 2026.

## آخر التعديلات المثبتة في السورس

- **جميع تصحيحات البناء السابقة**: `share_plus ^13.3.1`، Flutter 3.47/Dart 3.13، Gradle 8.14.3، AGP 8.13.2، Kotlin 2.3.0 بـ`compilerOptions`، JDK 17، مع إيقاف `shrinkResources` عندما `minify=false`.
- تصحيح قراءة `attempt` وعدم إمكان null، و`instantiateImageCodec` لصور Flame، واستعادة ملفات lib الكاملة من حزمة Recovery.
- مكتبة DOC 03: `lib/widgets/component_library.dart` بحالات مكونات قابلة لإعادة الاستخدام، وأصول PNG المعتمدة للأزرار بدل رسمها من الصفر، وقيم التصميم المعتمدة في `lib/core/theme.dart`.
- دمج المكونات في التنقل والمراحل والعوالم وHUD اللعب والنتائج والمتجر والمكافآت والمهام والإنجازات والإشعارات.
- عرض `pending` بدل رصيد وهمي قبل تأكيد الخادم، وحجز زر CTA أثناء العمليات غير المكتملة، ومنع زر الشراء عند عدم كفاية العملة.
- إعدادات Reduced Motion وصوت التفاعل وHaptics مستقلة ومحفوظة على الجهاز. صوت التفاعل الحالي هو نقرة النظام؛ لا يُعد حزمة SFX نهائية.
- اختبار مكونات إضافي `test/component_contract_test.dart` ومعاينة **للمطور فقط** `tool/component_gallery_main.dart` (ليست شاشة جديدة للاعب).

## التشغيل على الماك الحالي

**تنبيه ملفات الخطوط:** لا تحتوي ZIP على ملفات `.ttf` الثنائية. إذا كنت تفكها فوق `Game` الحالي على الماك فاحتفظ بـ`assets/fonts` الموجود. أما لتثبيت جديد فاستعد الخطوط من ZIP المصدر السابق الذي تملكه بالأمر:

```bash
python3 tool/restore_owner_fonts.py ~/Downloads/PuzzleQuest_Full_Source_Flutter_Flame_v1.1.1_Analyzer_Fixes.zip
```

**قبل التثبيت:** من المهم الاحتفاظ بمجلدَي `android/` و`ios/` المُوَلَّدين سابقًا على Mac، خصوصًا `gradle-wrapper.jar` و`Runner.xcodeproj` غير الموجودين في حزمة السورس القابلة للنقل. استبدل ملفات مصدر Game فقط، ولا تحذف مشاريع المنصتين.

افتح Terminal من مجلد `Game` ثم:

```bash
python3 tool/check_source_integrity.py
python3 tool/verify_doc03.py
flutter pub get
flutter analyze
flutter test
flutter run -d emulator-5554
```

لو تُنشئ مشروعًا جديدًا من هذا ZIP على جهاز جديد، شغّل `python3 tool/prepare_platforms.py` أولًا (تتطلب macOS مع Flutter/Xcode/CocoaPods وRuby gem `xcodeproj`). أداة `prepare_platforms` تعيد تصحيحات Gradle إلى ملفاتها لو استبدلتها قوالب Flutter أثناء الإنشاء.

معاينة جميع أصول حالات الأزرار والمكونات في بيئة التطوير:

```bash
flutter run -t tool/component_gallery_main.dart -d emulator-5554
```

عنوان API الافتراضي `https://puzzlequest.50sols.com/api/v1/`، واسم الحزمة `com.puzzlequest50sols.com`. لا توجد معلومات اتصال MySQL أو أسرار السيرفر ضمن هذا المجلد.

## حالة الأدلة

- على **ماك المالك بتاريخ 25 نوفمبر 2026**: `flutter pub get` نجح، و**11 اختبارًا** نجح بعد حزمة Recovery، ثم **فتح تطبيق PuzzleQuest فعليًا على Android Emulator** بعد Hotfix v1.1.4؛ ظهر تنبيه «الخدمة غير مهيأة» في واجهة الخادم. هذا دليل تشغيل **للنسخة السابقة**، وليس اختبارًا لهذه الحزمة الجديدة.
- إصدار **1.2.0+5**: اختبارات المصدر والأصول داخل الأرشيف فقط؛ لم يتم تشغيل `flutter analyze` أو `flutter test` أو محاكي Android/iOS بعد الإضافات الجديدة في هذه البيئة.
- معالج iOS الكامل وGoogle OAuth وAPNs/FCM وAdMob SSV وارتباط الخادم والموافقات القانونية واختبار 100 قطعة والمطابقة البصرية من بوابات الاعتماد المفتوحة.

تفاصيل عقد DOC 03 والقرارات غير المحسومة: `docs/DOC03_DESIGN_TO_DEVELOPMENT_AR.md` و`docs/DOC03_COMPONENT_MATRIX.csv`.
