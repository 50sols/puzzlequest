# Firebase — مراجع إعداد Android وiOS (تصميم فقط)

ملفا `android/google-services.json` و`ios/GoogleService-Info.plist` **نسختان مطابقتان للمرفقات الأصلية**؛ لا توجد شفرة تشغيل. المشروع Firebase موحّد، وحزمة Android ومعرّف iOS متطابقان. راجع `CONFIG_VALIDATION.json` لبصمات SHA-256.

**مهم:** ملفا العميل ليسا مفاتيح إرسال Push من Laravel، ولا مفاتيح APNs. لا تضف ملف خدمة Google الخاص أو مفتاح Apple `.p8` إلى هذا الأرشيف أو الملفات العامة. لا تعرض مفاتيح API في لوحة الإدارة أو التصميم.

## التنفيذ لاحقًا (ليس ضمن هذه الحزمة)
- Android: موضع ملف العميل داخل `android/app/google-services.json`، مع حزمة مطابقة وتفعيل أذونات النظام وقناة الإشعارات وأيقونتها الأحادية المخصصة؛ أصول الأيقونة الصغيرة لا تعتبر جاهزة بعد.
- iOS: موضع ملف العميل داخل `ios/Runner/GoogleService-Info.plist`، مع Bundle ID ومزايا Push Notifications وAPNs وربط مفتاح APNs في Firebase Console؛ لا تخلط APNs مع Apple Login المُلغى.
- Laravel: خدمة إرسال FCM HTTP v1 بمفاتيح بيئة محمية خارجة عن حزمة التصميم، مع سجل تدقيق وقيود PN01–PN04 ومنع التكرار.
- ملف Android المرفق لا يحتوي OAuth clients؛ يلزم التحقق من إعداد Google Sign-In والتواقيع الفعلية قبل تسليم تطبيق تسجيل الدخول.
- لا يثبت وجود ملف العميل تفعيل FCM/APNs أو وصول أي إشعار؛ اختبارات أجهزة Android وiOS أساسية.

مرجع Firebase الرسمي: https://firebase.google.com/docs/cloud-messaging/flutter/get-started


## مرجع OAuth Backend الجديد
وردت لقطة Google Cloud Web OAuth Client باسم `PuzzleQuest-Backend` ومعرّف عام مخزن في `../../02_DESIGN/GOOGLE_OAUTH_DESIGN_CONTRACT.json`. الصورة الأصلية والأسرار غير مضمنة. **اعتمد المالك عمدًا فصل المشروعين:** Cloud (`puzzlequest-515809`) لتسجيل Google وFirebase (`puzzlequest50sols`) لتطبيق الهاتف/Push. لم يتم إنشاء OAuth Native حتى الآن، وسيُستكمل أثناء التطوير عند توفر SHA/Bundle وربط SDK، مع اختبارات Google ID Token وLaravel Audience قبل قبول الميزة. الاختلاف ليس خطأ ضبط بحد ذاته. حقول JS origins وRedirect كانت فارغة؛ لا نخترع روابط، وقد يكون تركها فارغًا مناسبًا في مسار Native ID Token.
