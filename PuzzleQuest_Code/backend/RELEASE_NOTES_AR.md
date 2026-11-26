# PuzzleQuest Setup v1.0.1 — cPanel Fixed-Root Layout

- إعادة توزيع حزمة التثبيت في مجلدين شقيقين: `public_html` و`puzzlequest_app`، داخل ZIP واحد يفك مرة واحدة من Home في cPanel.
- نقطة الدخول العامة ومعالج `/install` يستخدمان Laravel خارج Document Root.
- تعيين `public_path()` إلى `public_html` لتعمل خدمة نشر المراحل والموارد والأيقونات.
- إصلاح مسارات تحديثات ZIP الموقّعة ونسخ الملفات الاحتياطية المشفّرة لتشمل مجلد الويب الفعلي، مع منع تحديثات البنية القديمة غير المتوافقة.
- التحقق من وجود البنية الصحيحة قبل تشغيل التثبيت. لا حاجة لتعديل Document Root أو SSH أو Composer/npm على استضافة الإنتاج.
- **الأهلية:** مرشح لاختبارات Staging فقط؛ فحوص Fresh Install وUpgrade وRecovery على MySQL/cPanel لم تُنفذ حتى الآن. ليست شهادة جاهزية إنتاجية.
- لا توجد تغييرات في قواعد لعبة V1 أو واجهات الحساب/المكافآت أو محتوى المراحل الخمس.


## v1.0.2 — تصحيح مسار الدومين الفرعي في cPanel
- تغيير وجهة الملفات العامة من `/public_html` إلى `/public_html/puzzlequest.50sols.com` دون المساس بـ50sols.com.
- تصحيح نقطة دخول `index.php` والمثبت و`public_path` ومسار فحص الصلاحيات.
- تغيير علامة توافق التحديث إلى `cpanel_fixed_subdomain_v1`؛ لا يعامل هذا Setup ZIP كتحديث لنسخة مثبتة.
- لم يتم اختبار Fresh Install على MySQL أو استضافة cPanel الفعلية.
