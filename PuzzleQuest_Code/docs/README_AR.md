# PuzzleQuest Studio + Laravel Remote Management — v1.1.0

هذه الحزمة **مبنية من `PuzzleQuest_Code(1).rar`**. الإصدار جديد لطبقة الإدارة ولا يعيد تثبيت Laravel ولا يحذف بيانات اللاعبين.

## الوظائف المُنفَّذة
- اتصال Python آمن بـ HTTPS + Token مؤقت (7 أيام)، يصدره حساب Owner من `/admin/studio`؛ مع إلغاء فوري وتدقيق العمليات.
- العوالم: إضافة عالم Draft، تعديل الاسم والترتيب قبل النشر، نشر/إخفاء بعد فحوص مراحل منشورة.
- المراحل: إنشاء مسودة مرحلة، عنوان وترتيب وربط سابق، استيراد ZIP مُختبر، عرض Revision UUID ونشر باعتماد Device QA، وإلغاء النشر.
- استوديو المحتوى: Collection / Level Group / World Art / Village Scene / Village Item / Event / Mission / Achievement / Banner / Story.
- الصور: PNG/JPEG/WebP، حد 8 MB و12 مليون بكسل، SHA-256 وUUID وروابط أصلية دون استبدال صامت.
- محرر تخطيط القرية: خلفية، عناصر، إحداثيات 0..1، سحب للتوزيع، Scale، ترتيب طبقات Z، ارتباط المبنى ومرحلة 0..4.
- Publish: Draft Revision متغير + Snapshot منشور غير قابل للتعديل + History + Restore to Draft + Retire.
- API عامة للمحتوى المنشور: `/api/v1/studio-content` ومعلومات مختارة داخل كتالوج اللعبة وواجهات القرية والمجموعات. الفعاليات لا تُعرض خارج نافذة البداية/النهاية.
- لا تعدّل هذه الإضافة رصيد اللاعب ولا المشتريات ولا تمنح مكافآت من مستندات جديدة تلقائيًا.

## مهم: حدود التكامل
**الأرشيف لا يحتوي سورس Flutter**. لذلك إدارة المحتوى وتشغيل API ونشر الصور تعمل في Laravel، لكن ظهور كل الخلفيات والعناصر والفعاليات على شاشة اللاعب فعليًا يحتاج أن يقرأها تطبيق Flutter ويعرضها. لم نختبر عرضها على جهاز. `Mission` و`Event` هنا تعريفات محتوى وتوقيت، وليست منطق توزيع Coins/Hints أو Push تلقائيًا.

## التثبيت بدون SSH (بعد التثبيت الأصلي)
1. تحقق من إصدار Laravel الفعلي في **لوحة الإدارة → تحديثات النظام والنسخ (Module 11)**. اختر **Update ZIP** المطابق لـ `Current Version` حرفيًا (`1.0.0` أو `1.0.2`). لا ترفع الحزمتين.
2. تحديثات لوحة الإدارة الأصلية تتطلب مفتاح Ed25519 عام متوافقًا مع توقيع ZIP. **ملاحظة خلل قديم مهم**: دالة التحقق في النسخة الأصلية تقرأ `RELEASE_PUBLIC_KEY` من config/.env وليس من الحقل المحفوظ في قاعدة البيانات. لذلك عند استخدام مفتاح الحزمة المرفق للمرة الأولى، أضف `RELEASE_PUBLIC_KEY=...` إلى `.env` من **cPanel File Manager** خارج `public`، ما لم يكن لديك مفتاح موثوق مطابِق. تعديل `.env` يتم بصلاحية مالك الخادم فقط؛ لا تنشره ولا تضع فيه المفتاح الخاص.
3. داخل **Module 11** اضغط `Verify ZIP`، ثم بعد ظهور معرف النسخة Verified خذ Backup، أكد هوية Admin، ثم `Install Update`. يبدأ النظام وضع الصيانة ويشغّل Migration. لا تعيد تثبيت المشروع.
4. راجع `/health` و`/api/studio/v1/schema` (الـAPI يتطلب Token)، ثم افتح `https://puzzlequest.50sols.com/admin/studio` بصلاحية Owner. إذا فشل التحديث ولا يزال الموقع في الصيانة، استخدم آلية Recovery الأصلية والنسخة المشفرة ولا تكرر التحديث عشوائيًا.
5. من `/admin/studio`: أنشئ Token باسم جهازك بعد تأكيد كلمة مرورك. يظهر لمرة واحدة فقط؛ انسخه إلى **Online Manager** في تطبيق Python. لا تُدخل كلمة مرور لوحة الإدارة في Python.
6. شغّل `PuzzleQuest_Studio/launch_windows.bat` أو `launch_mac.command`، وافتح **Open Online Manager**.

## تعديل القرية
- افتح تبويب **Image Asset Library** وارفع خلفيات وصور المباني والعناصر، ثم انسخ UUID لأي صورة.
- افتح **Collections • Events • Village • More** واختر نوع `village_scene`، اضغط **New Template**، واكتب World ID موجودًا.
- اضغط **Village Visual Editor**، اختر صورة الخلفية ثم أضف عناصر واسحبها إلى المواضع المطلوبة؛ Scale وStage وBuilding ID متاحة. اضغط **Send Layout to Draft Editor**، ثم **Create Draft**، وبعد المعاينة **Publish**.
- يمكن للمستخدم النهائي الحصول على JSON والصور عبر `GET /api/v1/studio-content?kind=village_scene` (يظهر المنشور فقط)، ويحتاج عميل Flutter إلى دعم العرض.

## ملاحظات الأمن
- صلاحيات Owner لإصدار الاتصال، وOwner/Content للاستخدام، والـToken مشفّر بالتجزئة في قاعدة البيانات ويُلغى من اللوحة. TLS إجباري على العميل.
- الرفع لا يسمح بـSVG خارجي أو ملفات تنفيذية. SVG الخاص بأقنعة Jigsaw يخضع لمسار `Content::import` والتحقق المنفصل.
- إعادة نشر صور ومراحل موجودة لا يمحو الـRevision السابق. عمليات Draft مقيّدة بـ optimistic locking لحماية عمل المحرر.
- `release.sig` يتضمن توقيع Ed25519 موثوق، و`release.json` يتضمن SHA-256 لجميع ملفات التحديث.
- أبقِ مفتاح التوقيع **الخاص** خارج الاستضافة والـZIP والملفات العامة؛ `release-public-key.txt` عام فقط.

## حالة التحقق — ما تم وما لم يتم
- `php -l` للفيلات المعدلة: PASS.
- Laravel `route:list --path=studio`: PASS، 24 مسارًا.
- اختبارات Python الخاصة بـ Remote API وLauncher: PASS.
- اختبارات Laravel Feature/DB المتقدمة موجودة في `backend/tests/Feature/StudioRemoteManagementTest.php`، ولكن **لم تُنفَّذ** في بيئة التجهيز لغياب PHP extensions `dom`, `mbstring`, `xmlwriter`, `pdo_sqlite`, `gd`. لا تعتبر إصدارًا مثبتًا أو جاهزًا للإنتاج قبل اختبارات قاعدة البيانات وFresh Upgrade وHealth Check على بيئة مكافئة.
- لا يوجد Commit Git SHA من RAR؛ لا ندّعي GitHub CI أو Merge أو تثبيتًا حيًا.

## إدارة التحديثات القادمة
`release-tools/build_signed_release.py` يشرح/يبني Manifest وZIP من سورس واحد، ويستخدم مفتاح Ed25519 الخاص من ملف خارج المستودع. لا تضع المفتاح الخاص في source ZIP أو GitHub.
