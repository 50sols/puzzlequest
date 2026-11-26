# اختبارات تطبيق PuzzleQuest

- `puzzle_rating_test.dart`: حدود النجوم، الفشل، والخصم من Score وفق Q05.
- `bundled_content_test.dart`: المراحل الخمس وأزمنتها، وعدد القطع وملفات القطع المضمنة.
- `screen_coverage_test.dart`: تعريف معرّفات الشاشات الأربعين.

هذه ملفات اختبارات مصدرية **لم تُشغّل في حزمة الإنشاء الحالية** لأن Flutter/Dart SDK غير مثبت في بيئة الفحص. عند توفر SDK يجب تشغيل `flutter pub get && flutter analyze && flutter test`، ثم الاختبارات التكاملية على Android/iOS وخادم Laravel اختبار حقيقي. وجود الملفات وحده لا يساوي PASS.
