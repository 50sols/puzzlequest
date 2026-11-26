# PuzzleQuest v1.0.2 — تثبيت cPanel بدومين فرعي ثابت

**مخصص لتوزيع الاستضافة المؤكد من صور cPanel:**

- نطاق اللعبة: `puzzlequest.50sols.com`
- Document Root الحالي: `/public_html/puzzlequest.50sols.com`
- مجلد Laravel الخاص: `/home/solscool/puzzlequest_app`
- ملفات الدومين الرئيسي `50sols.com` تظل داخل `/public_html/` كما هي.

## تحذير قبل رفع أي ملف

1. **لا تستخدم نسخة v1.0.1**؛ كانت تضع `index.php` في `/public_html` الخاص بالموقع الرئيسي، وهي غير مطابقة لصور استضافتك.
2. من cPanel File Manager، أنشئ **Backup** لمجلد الدومين الفرعي الحالي ولمجلد `puzzlequest_app` إن وجد، قبل استبدال الملفات. افحص وجود `puzzlequest_app/.env` أو `puzzlequest_app/storage/installed.lock`. **إذا كان أحدهما موجودًا، لا تستخرج Setup ZIP فوق النسخة المثبتة**؛ تحتاج خطة تحديث آمنة بدل التثبيت النظيف.
3. لا ترفع ملف ZIP إلى مجلد الدومين الفرعي ولا تفكه داخل `public_html`.
4. تأكد من وجود SSL صالح لـ`puzzlequest.50sols.com`، واختيار PHP 8.3/8.4 وإضافات `ctype`, `curl`, `dom`, `fileinfo`, `mbstring`, `openssl`, `pdo`, `pdo_mysql`, `sodium`, `zip`, `gd`, `xml`.

## طريقة ONE ZIP دون SSH

1. افتح **cPanel → File Manager → Home**: المسار `/home/solscool/`، وهو المجلد الذي يحتوي على `public_html` و`puzzlequest_app`.
2. ارفع `PuzzleQuest-Setup-v1.0.2-cPanel-Subdomain.zip` إلى **Home** واضغط Extract **مرة واحدة في Home**.
3. هيكل المجلدات الناتج:

   ```text
   /home/solscool/
   ├── public_html/                   ← 50sols.com (لا نستبدل ملفاته)
   │   ├── index.php                  ← ملفات الموقع الرئيسي الحالية لا تتغير
   │   └── puzzlequest.50sols.com/   ← Document Root الخاص باللعبة
   │       ├── index.php
   │       ├── .htaccess
   │       ├── install/
   │       ├── content/
   │       └── fonts/
   └── puzzlequest_app/               ← Laravel وvendor وstorage خارج الويب
       ├── app/ bootstrap/ config/ database/ resources/ routes/ vendor/
       └── storage/
   ```

   إذا كان مجلد الدومين الفرعي يحتوي `.user.ini` أو `php.ini` فلن يستبدلهما ZIP؛ احتفظ بهما. افحص قبل استبدال `.htaccess` في مجلد الدومين، واحفظ نسخة منه.
4. من **cPanel → MySQL Databases** أنشئ قاعدة بيانات **فارغة جديدة** ومستخدمًا واربطه بصلاحيات الجداول. هذه خطوة قد تتطلبها استضافتك ولا يستطيع المعالج تجاوزها.
5. افتح **https://puzzlequest.50sols.com/install/**. إذا تعذّر فتح HTTPS، عالج SSL أولًا من cPanel؛ لا تستخدم HTTP لإدخال بيانات الإدارة.
6. من File Manager افتح `puzzlequest_app/storage/app/private/install.key` وانسخ **رمز التثبيت الخاص** إلى المعالج؛ لا تشاركه مع أي شخص.
7. أدخل بيانات MySQL واسم Super Admin وبريده وكلمة مروره ثم Finish. بعد النجاح يجب قفل المثبت وفتح `https://puzzlequest.50sols.com/admin/login`.
8. من لوحة الإدارة اضبط البريد الإلكتروني وCron وGoogle OAuth وFirebase/APNs وAdMob والصفحات القانونية. تعطيل هذه التكاملات لا يُعتبر اختبار نجاح لها.

## ملاحظات قبول

- هذه **حزمة مرشحة لتجربة تثبيت نظيف على Staging**، وليست شهادة جاهزية إنتاجية؛ MySQL Fresh Install/Upgrade وBackup Restore على الاستضافة لم تختبر بعد.
- تحديثات ZIP تتطلب توقيعًا رقميًا موثوقًا و`deployment_layout=cpanel_fixed_subdomain_v1`، ولا يجوز استخدام Setup ZIP كتحديث لنظام مثبت.
- ملفات Laravel الخاصة وأسرار `.env` خارج Document Root. لا تضع أي مفتاح أو قاعدة بيانات داخل مجلد الويب.
- ملفات cPanel للموقع الرئيسي تبقى بدون تعديل. المجلد الخاص بالدومين الفرعي وحده يتلقى أصول الواجهة.
