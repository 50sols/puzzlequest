# ADM13 — شاشات إعدادات الإدارة (تصميم فقط)

ثمانية ملفات SVG قابلة للتعديل مع ثماني معاينات PNG، جميعها ضمن وحدة إعدادات النظام الحالية إداريًا؛ لا شاشة لاعب إضافية، ولا كود Flutter/Flame/Laravel. تنقل Tabs بين عام وFirebase Android وFirebase iOS وسياسة Push والحساب والأمان والخصوصية والدعم والاستضافة والمهام وGoogle OAuth Backend. إعدادات System Updates موجودة أصلًا في ADM11، وإرسال Push في ADM12؛ لا نكرر مميزاتهما.

**التسليم:**
- `01_GENERAL.svg` الهوية واللغات والدومين.
- `02_FIREBASE_ANDROID.svg` Firebase Client Android وFCM وأذونات Android وGoogle OAuth.
- `03_FIREBASE_IOS.svg` Firebase Client iOS وAPNs وأذونات iOS؛ Apple Login غير موجود.
- `04_PUSH_POLICY.svg` قواعد PN01–PN04 وحدود Push وصمت الليل.
- `05_AUTH_SECURITY.svg` كلمة المرور وOTP والجلسات والضيف.
- `06_PRIVACY_SUPPORT.svg` الخصوصية والدعم وتصدير/حذف البيانات.
- `07_HOSTING_JOBS.svg` cPanel وCron والـQueue وHTTPS وSetup/Update ZIP.

كل شاشة لها نظائر `*_PREVIEW.png`. القيم هي قرارات المالك أو حالات «لم يُتحقق». لا يوجد حقن مفاتيح أو اختبار اتصال مخفي.

**حالات السلوك للتنفيذ لاحقًا:** عند تحميل الحقول تظهر حالة الانتظار دون أرقام مزيفة؛ عند غياب ملف الخدمة تظهر `not_configured` وخطوة مسؤول مخول؛ عند فشل التحقق لا يصبح الوضع `active`؛ لا تظهر إلا قيمة Masked للبيانات السرية؛ مراجعة الدور وسجل تدقيق عند أي تغيير؛ لا تسمح واجهة التصميم بتغيير السياسات دون تفويض موثق؛ تعديلات Firebase/APNs/Queue تتطلب بيئة حقيقية واختبارًا منفصلًا.

**Firebase:** العميلان متطابقان في Project ID ورقم Sender ومعرّف التطبيق. ملف Android لا يحتوي OAuth client؛ إعداد Google Sign-in وحزم التوقيع يحتاج مراجعة قبل النشر. iOS يحتاج مفتاح APNs وسجل صلاحيات في Firebase Console. لا توجد مفاتيح إرسال خادم ضمن التسليم. سياسة 13+ وتفعيل مناطق العالم يخضعان للمراجعة القانونية.


- `08_GOOGLE_OAUTH_BACKEND.svg`: المرجع العام OAuth Web Client وعلاقة المشروعين ومتطلبات إثبات تسجيل Google على Android/iOS. لا أسرار ولا تشغيل حي.

**قرار مالك المنتج معتمد 25 نوفمبر 2026:** Cloud `puzzlequest-515809` لتسجيل Google منفصل **بقصد** عن Firebase `puzzlequest50sols` لتهيئة التطبيق والإشعارات. المعرّف Android/iOS هو `com.puzzlequest50sols.com`. لم يُنشأ Native OAuth بعد؛ يُنشأ **أثناء التطوير** بعد معرفة شهادات التوقيع/بيانات ربط المنصتين وقبل اختبارات قبول تسجيل الدخول. اختيار SDK وآلية التوكن والتحقق في Laravel مسؤولية التنفيذ؛ لا يُدّعى التفعيل الآن ولا تُفترض قيم Redirect. تفاصيل الأدلة في `../../02_DESIGN/GOOGLE_OAUTH_DESIGN_CONTRACT.json`.