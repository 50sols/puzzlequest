# خطة تطوير Backend للعبة PuzzleQuest — Laravel / API فقط

> **وثيقة هندسية تخطيطية لا كود تشغيل ولا عقد API معتمد.** نطاق اللعبة ثابت: 40 شاشة، 5 صور/20 تكوين Puzzle و4 أحجام قطع موجودة، مبنيا cottage/windmill، الحسابات والضيف والمهام والمكافآت والإعلانات والمتجر الموجودة. لا نضيف شاشة منتج أو نمط لعب أو اقتصادًا جديدًا. بنود المنتج ذات الأرقام معلقة على `OWNER_DECISIONS_AR.md`؛ لا ينفذ المطور تقديراتها باعتبارها سياسة.

## 1. حدود المسؤوليات

- **Flutter:** عرض الحالات والنصوص والأزرار والواجهات الأربعين وأذونات النظام؛ تنسيق المصادقة والجلسات والتخزين المحلي.
- **Flame:** عرض اللوحة/الصينية، تحويل الإحداثيات، السحب، Hit Test، Snap، وقص/تراكم القطع. لا طلب سيرفري عند كل حركة Pointer، ولا منح مكافأة داخل Flame.
- **Laravel API:** هوية الحساب والجلسات، محتوى العوالم والمراحل وإصدارات الأصول، تقدّم مؤكد، أرصدة وLedger، أهلية Claim/Buy/Repair، الإعلانات المكافأة، المشتريات، Daily/Missions/Events، Leaderboard، Collections/Achievements، الإشعارات، إعدادات الخصوصية والتصدير والحذف، ومساعدة المستخدم الموجودة.
- **Guest Offline:** تقدّم جلسة اللعب محلي حتى ربطه وفق السياسة المعتمدة، مع فصل حالة الصورة المكتملة محليًا عن الأرصدة/الاستحقاقات المؤكدة من الخادم. عند تعارض الحساب والضيف لا تفترض سياسة دمج؛ واجهة الشاشة 29 تعرض عدم الحسم.

## 2. نماذج بيانات أولية — ليست اقتصادًا أو شاشات جديدة

|المجموعة|كيانات تخزين محتملة لخدمة الشاشة القائمة|قيد سلامة|
|---|---|---|
| الهوية | accounts, external_identities, sessions, email_challenges, guest_links | فصل OTP التحقق عن الاستعادة، إعادة الإرسال محدودة |
| المحتوى | worlds, levels, level_asset_revisions, difficulty_config | 5 master فعلية؛ أي زيادة تحتاج أصولًا معتمدة وmanifest version |
| التقدم | game_attempts, board_snapshots, level_results, user_unlocks | هوية ثابتة للمحاولة/المستوى/الصعوبة/توقيع إصدار المحتوى؛ لا إعادة توزيع مكافأة مؤكدة |
| الاقتصاد | wallets/holdings, ledger_entries, reward_claims, entitlements | المعاملات ذرّية وunique idempotency key؛ لا رصيد بلا سجل |
| إعلان/شراء | rewarded_ad_events, verification_callbacks, purchase_receipts | توقيع المزود، transaction_id فريد، حالة pending/verified/rejected |
| القرية | user_building_states, building_transitions | stage 0–4 للمبنيين فقط، انتقال وخصم معًا في Transaction |
| المحتوى الاجتماعي القائم | missions, events, progress, collections, achievements, leaderboard_snapshots | لا توليد قواعد لعب أو جائزة من screenshot |
| الخصوصية والخدمات | consent_records, privacy_requests, notifications, support_requests, audit_events | صلاحيات صاحب السجل، احتفاظ وحذف وفق سياسة معتمدة |

أسماء الجداول أمثلة لتقسيم المسؤوليات وليست التزامًا بمخطط نهائي أو ميزة إضافية. الصلاحيات ومكان التخزين يحددهما التقييم الأمني ووثيقة الخصوصية.

## 3. عائلات العمليات API المقترحة (غير مجمدة)

1. **Account/Auth:** register/login/logout, Google/Apple وفق القرار، verify/resend OTP، forgot/reset، profile/avatar، email-change، devices، export/delete، consent.
2. **Content:** bootstrap/version/worlds/levels/asset manifests، شروط فتح العناصر، الحصول على تكوين المرحلة المسموح وصلاحية أصوله.
3. **Progress:** open attempt، save/resume snapshot، submit completion، inspect pending/confirmed result، replay دون منح مكرر؛ يجب تصميم تحقق معقول ضد تزوير إنجاز العميل. لا يفترض أن خادم API قادر على إثبات كل حركة قطعة بمجرد نتيجة مرسلة.
4. **Economy:** balance/ledger، hint/shuffle/full-image entitlement، shop offer/checkout/receipt verification، chest/daily/mission claim، village state/repair. كل تأثير مالي/مكافأة في معاملة مع قفل ومنع طلب مكرر.
5. **Ads:** issue ad context، receive provider signed SSV callback، resolve pending rewards، timeout/retry بنفس العملية. إذا اختير Google AdMob، يُتحقق من توقيع ECDSA/key_id وtransaction_id قبل الإثبات؛ لا يُوثق callback من التطبيق وحده. المرجع: https://developers.google.com/admob/android/ssv
6. **Community/content:** read leaderboard, missions/events, collections/achievements, inbox/read-all، help/support وفق القنوات القائمة فقط.

كل عمليات التغيير تستلزم جلسة/صلاحية وRequest ID للـidempotency حسب النوع. REST هو خيار تنفيذي مقترح وليس قرار منتج جديدًا؛ لا يُجمّد أي Endpoint قبل إجابات الأسئلة واعتماد العقود.

## 4. تسلسل التنفيذ والبوابات

|الموجة|المخرجات المطلوبة|تعريف النجاح قبل الانتقال|
|---|---|---|
| P0 — اعتماد المنتج | إجابات Q01–Q40، حقوق الخط/الشعار، خريطة العالم/الأصول، سياسة التجربة/الأمان؛ فصل أسئلة النشر Q41–Q42 | لا توجد قاعدة عمل أساسية مجهولة ولا نقص أصل مطلوب |
| P1 — الهيكل والأمان | API versioning، migrations، config، identity/sessions/OTP، roles للحساب والإدارة، audit، OpenAPI وصفية | اختبارات صلاحيات وOTP وrate-limit وseed نظيف |
| P2 — اللعب/التقدم | خدمة كتالوج مع Asset version hash، attempts، sync snapshot، completion pending/confirmed، replay | اختبارات duplicate/offline/conflicting asset revision وعدم كشف رصيد قبل التأكيد |
| P3 — الاقتصاد/القرية | ledger، claims، daily/chest/shop، مبنيان 0..4 مع انتقالات مصادق عليها، missions/achievements | خصم/منح مرة واحدة فقط حتى عند retry/concurrency |
| P4 — الخدمات والتكاملات | Google/Apple/SMTP عند الاعتماد، إعلان SSV، internal Coins-purchase invariants (no real-money IAP), support/privacy/export/delete، notifications/leaderboard | اختبارات Provider signature/replay/failure/consent/no-data-leak |
| P5 — الدمج والأداء | تطبيق Flutter/Flame على API، معالجة Offline والخلفية، اختبار 100 قطعة، لوحات صغيرة ونص كبير، تحميل أصول | سيناريوهات End-to-End موثقة وقياسات فعلية من الأجهزة |
| P6 — نشر Laravel | Setup/Update ZIPs، web installer، backup/recovery، admin updates، GitHub Actions fresh-install/upgrade | نجاح اختبارات ZIP الفعلية على بيئة نظيفة وإصدار سابق، وتحقيق متطلبات الأمان والنشر |

الموجات من أجل التخطيط فقط؛ لا تنفذ P3/P4 بأرقام/خدمات غير معتمدة، ولا تعني P5 أو P6 أنها اختبرت الآن.

## 5. قواعد التشغيل/الأمان المطلوبة قبل البناء

- استخدام **Laravel 13.x أو إصدار مدعوم وقت التنفيذ** بعد فحص PHP والإضافات والتوافق الفعلي مع cPanel/VPS؛ عدم تثبيت إصدار قبل اختبار الاستضافة. المصدر: https://laravel.com/framework/docs/releases
- مصادقة API للجلسات/الأجهزة وحماية الطلبات المتكررة مع Rate Limiting والحد الأدنى من البيانات. لا مفاتيح API في حزم التنزيل العامة أو التطبيق.
- احسب الرصيد ونقل حالات المبنى من قواعد موثقة فقط؛ `ledger_entries` و`reward_claims` محمية بقيود فريدة وtransactions. اجعل Server Time مرجع اليومية والمواسم.
- عند استحقاق الإعلان راجع التوقيع بمفاتيح المزود، اربط الحدث بالمحاولة ونوع المكافأة والمستخدم، ولا تمنح على أساس حدث UI. Callback المكرر يعيد الحالة دون تكرار الرصيد.
- التقدم المحلي قابل للاستئناف عند انقطاع الشبكة، لكن السيرفر لا يثق بالقيم الاقتصادية المرسلة من العميل. عند تبديل إصدار الصورة/القطع لا تخلط Snapshots من إصدار آخر.
- إذا تطلب Sync حل تعارض غير معتمد، احفظ النسخ ولا تخمّن اختيارًا أو تنشئ شاشة دمج جديدة.
- الوضوح في الخصوصية: الموافقات المسجلة بنسخة نص وتاريخ ومصدر، تصدير/حذف بإذن المالك وفق متطلبات المنطقة والقاصرين؛ حذف حساب لا يُسمى ناجحًا حتى تثبت نتيجته الفعلية.
- GitHub Actions: اختبارات Laravel وحدات/تكامل/أمان، عدم تسرب الأسرار، فحص APIs/صور/بصمات Asset، وحالات السباق وقطع الاتصال واسترداد الأرصدة.

## 6. معيارك الدائم: ONE ZIP → WEB SETUP → LIVE SITE → ADMIN ZIP UPDATES

الحزم الحقيقية المقررة للـLaravel Backend في **مرحلة التطوير**، وليست مرفقة الآن لأنها ليست كودًا:

- `PuzzleQuest-Setup-vX.Y.Z.zip`: جميع مصادر Laravel runtime + production vendor + compiled assets + Installer Web `/install` أو `/setup`، فحص PHP/extensions/permissions/database/document-root، إنشاء `.env` وAPP_KEY، migrations/seed، إنشاء Super Admin، Mail/Queue/Cache/Storage/Scheduler وفحص نهائي ثم Lock.
- `PuzzleQuest-Update-vX.Y.Z.zip`: آلية `Settings → System → System Updates` في لوحة إدارة Laravel حين تُنفّذ، مع Current/Latest Version وUpload/Verify/Backup/Install/Progress/Release Notes/History/Recovery.
- التحديث: **Verify trusted digital signature + SHA-256 + version compatibility → verified backup → maintenance/lock → safe file apply → migrations → cache rebuild → health check**. حماية ZIP Slip وsymlinks وإصدارات غير موثوقة، وعدم افتراض قابلية Rollback لكل Migration.
- النشر: cPanel/Shared Hosting/VPS دون أوامر composer/artisan/npm يدوية من المستخدم على خادم الإنتاج، مع شرح الخطوات التي لا تتخطى الصلاحيات (إنشاء DB وتعديل document root أو Cron)، وبديل موثق عندما لا يتاح Cron/Queue، وعدم الادعاء بأن scheduler يعمل بلا وسيلة تنفيذ فعلية.
- GitHub Actions من **Commit واحد** ينتج Setup + Update + manifests + SHA256 + signed release notes وBuild info. فحوص Fresh Install وUpgrade باستعمال **نفس** ملفات ZIP النهائية، وحفظ الحسابات والأرصدة والرفع والإعدادات؛ لا يكفي مجرد نجاح Build.
- لا إعلان أن النظام جاهز للإنتاج دون Release Artifacts حقيقية وCI نجاح على أحدث commit وFresh Install/Upgrade مثبتين. يرجع قرار دعم Shared Hosting إلى قدرة الاستضافة الفعلية على استضافة PHP والجداول والمهام المطلوبة.

## 7. خطر يجب اختباره في التنفيذ وليس حله بافتراض من المصمم

- **100 قطعة**: العتبة الحالية 21/960 من اللوحة أو 7.83dp عند 358dp؛ لا يوجد قياس UX على جهاز. فحص الصور/الهندسة لا يثبت سهولة اللعب.
- **خط Lato 500**: غير موجود في المصدر المرفق، ولا يصح تركيب وزن أو تغيير توكنات الخط دون اعتماد. الملفات الثنائية منفصلة عن ZIP التسليم هذا حسب `00_SHARED/fonts/README_AR.md`.
- **مصادقة الأرباح/المشتريات**: منصة الإعلانات والدفع لم تُعتمد؛ لا تفترض AdMob/App Store حتى يختارهما المالك.
- **المراحل**: 5 masters فقط؛ لا يملأ backend الـWorlds أو Leaderboard بمحتوى تجريبي بغرض إنتاجي.

**النتيجة الحالية:** خطة تنفيذ ممكنة، لكن لا يبدأ تنفيذ السلوك الاقتصادي/الخدمات على افتراضات. اقرأ `OWNER_DECISIONS_AR.md` واحصل على قرارات المالك قبل تجميد العقود والمخططات النهائية. لم يُكتب أو يُختبر مشروع Laravel/Flutter/Flame في هذه الجولة.

## Q01–Q12 — تحديث العقود بعد الاعتماد
- الكتالوج المرحلي: خمس مراحل منشورة داخل Green Valley بمعرّفات مصدر الأصول الحالي، بقطَع 16،16،36،64،100. Snow Land وDesert Ruins غير منشورين حتى يعتمد المحتوى المكتمل. الـAPI يرسل العالم والمرحلة وmanifest ونوع القطع من البيانات.
- التقدّم: 1-1 متاح، وفتح التالية عندما تؤكد السابقة بنجمة واحدة على الأقل. أفضل نتيجة لكل لاعب+مرحلة فقط؛ فرق النجوم الموجب، 500 Coins عند أول إكمال فقط. استحقاق مستقل للمحاولة/الإكمال مع idempotency key فريد وقيد DB.
- التقييم: خدمة الخادم تعتمد الوقت والمساعدات المستعملة ووقت إضافي؛ لا تُجمَّد العقود الرقمية حتى Q05-T/Q05-X.
- رصيد الإنشاء/الضيف مرة واحدة لكل الهوية: 300 Coins + 2 Hints. عند Upgrade ضيف لا إعادة منح. Ledger لتخصيص وعكس العمليات بطريقة معروفة، وPending ليس balance قابلًا للصرف.
- Items: hint=100 Coins، shuffle=150، full_image=200، starter_pack=400 لمرة واحدة، بلا سداد حقيقي في الإصدار الأول. الشراء المباشر والتطبيق في محاولة Shuffle معاملة ذرية، وحالات استهلاك Full Image المرتبطة بالمحاولة تحمي من التكرار.
- Ads: حق 10 ثوانٍ للصورة بعد إعلان موثق؛ حد 3 إعلانات تلميح في يوم UTC و1 للمحاولة. Full Image المدفوع 30 ثانية بعد التفعيل، لا تراكب. الـBackend يثبت منح الإعلانات ولا يمنح لمجرد callback العميل.
- Daily UTC: 7 أيام؛ رصيد Claim واحد لكل تاريخ UTC؛ لا reset للتقدم عند تفويت يوم، ويزيد مؤشر الدورة فقط بعد منح مؤكد. منع concurrent claims/clock spoof.
- **لوحة الإدارة المصممة فقط:** `04_BACKEND_DESIGN/SCREEN_INDEX.json` وملفات SVG + DESIGN.json وREADME. لا صفحات تطبيق إضافية أو Backend مكتوب.
- خطة الاستضافة والـZIP installer/admin updates **مستقبلية** ضمن التصميم، ولا يعني هذا وجود Build أو CI أو Release.

## إضافة متطلبات Q13–Q21 ونشر محتوى بازل بعد الإطلاق — عقد تصميمي

- **Content**: Laravel يقدم `catalog_version`, world/level ids, sequence, supported piece_count, manifest/image URLs, hashes, rating thresholds, published flags. ADM02/ADM03 Upload→Validate→Preview→Publish؛ تحقق حقيقي من حزمة القطع/الأقنعة والصورة والمراسٍ والحدود والتوقيع/البصمة قبل النشر. Assets immutable وقابلية استكمال محاولة قديمة على إصدارها؛ لا يتطلب إضافة مراحل متوافقة إعادة نشر Flutter. أي Schema/Geometry/سلوك جديد خارج ما يدعمه العميل يجب أن يُحجب حتى تحديث التطبيق. راجع `02_DESIGN/CONTENT_PUBLISHING_CONTRACT.json`.
- **Mission cycle**: جدول تعريفات خمسة IDs، دورات UTC وحركات تقدّم لا تتضاعف مع retry/replay للأحداث نفسها، وClaim idempotent قبل انتهاء الدورة؛ إعادة تشغيل مرحلة محسوبة إذا كانت محاولة نجاح مختلفة. Events فارغة بلا أي بيانات وهمية في الإصدار الأول.
- **Achievements/Collections/Chest**: خمسة achievements محسوبة خادميًا؛ خمسة الصور وثوابتها تفتح أول إكمال، badges تلقائية بلا مكافأة اقتصادية. Chest ثابت على *مراحل الإطلاق الخمس* و10 نجوم بينها فقط، 300 Coins + 2 Hints عبر Claim ذرّي مرة واحدة، لا ترتبط زيادة المراحل مستقبلًا به تلقائيًا.
- **Weekly Global**: موسم [الاثنين UTC 00:00، الاثنين التالي)؛ نتيجة واحدة أفضل لكل player+level+season، Score Q17 وTie break المعتمد، لا ظهور ضيف غير مُحقَّق ولا مال للمراكز. **Q05-T** شرط Level Time Limit لكل مستوى قبل تفعيل Leaderboard وقياس السرعة.
- **Village ledger**: Cottage stage 0→4 requires levels [1-1,1-2,1-3,1-4] + [100,200,300,400] Coins؛ Windmill [1-2,1-3,1-4,1-5] + [150,250,350,450] Coins، Atomic state-and-debit. لا مبانٍ إضافية أو Gems.
- **Ads**: AdMob SSV signed callback verified server-side; pending vs confirmed, unique `transaction_id` and `reward_request_id`, tie to player/reward/attempt/time. Interstitial after confirmed Claim and at least second successful completion per session, cap 2/session, 6/day UTC, 180s between, idle timeout 30m. No interrupt gameplay. Consent and age/markets remain release gates Q34/Q35.
- **No runtime**: لا API، DB، ملف نشر، تكامل AdMob، Flutter أو Flame مكتوب أو مُشغَّل في تسليم التصميم هذا. اختبارات الأداء/حماية replay/النسخ الاحتياطية تكون في التطوير لا في فحص ملفات SVG.

## تحديث بيئة الإطلاق والوقت 2026-11-25
- **Laravel على cPanel**، حتى PHP 8.4 متاح وفق المالك؛ التوافق النهائي لإصدار Laravel يتطلب معرفة إصدار PHP الفعلي والإضافات وقاعدة MySQL/MariaDB. لا composer/artisan/npm يدويًا على الخادم وفق معيار التثبيت المعتمد.
- **Android وiOS من V1**. مراحل Green Valley الخمس وقواعد الوقت في `LEVEL_CATALOG.json`، وScore بدون Extra Time. لا إصدار تطبيق للمراحل الإضافية المتوافقة المنشورة من لوحة المحتوى بعد نجاح التحقق.
- **سلوك المؤقت:** حالة المحاولة تحتوي `attempt_id`, `asset_revision`, `remaining_active_seconds`, `last_active_foreground_duration`، مع إيقاف العد عند Pause/Background/Ad والعودة دون احتساب فترة التوقف؛ تنفيذ التخزين والتوقيت يُختبر لاحقًا. لا تثق في الوقت المرسل من العميل لمنح Score/Coins دون تحقق ملائم.
- **Full Image paid**: استحقاق/تفعيل مرة واحدة بعملية ذرية يربط `preview_entitlement_id` بالمحاولة، و30 ثانية مشاهدة فعّالة في المقدمة مع استرجاع المتبقي بعد Restart؛ الاستحقاق لا يُكرر، والـ10 ثوانٍ الإعلانية لا تبدأ قبل AdMob SSV.
- **Shuffle Pause**: استخدام مخزن أو شراء+تطبيق 150 Coins بعد Confirm من نفس نافذة Pause، ومنع العملية عند <2 قطع غير ثابتة؛ جميع حالات السباق والفشل لا تؤدي لخصم جزئي.
- **صفحات ويب Backend الحالية اللازمة للروابط**: خصوصية وشروط وحذف ومساعدة، دون افتراض روابط URL أو محتوى قانوني نهائي قبل Q32–Q35؛ الهدف نطاق `puzzlequest.50sols.com`. HTTP المرسل لا يثبت TLS؛ يجب استخدام HTTPS للعملية الفعلية.
- **الأسواق:** متاح عالميًا وفق المالك، مع عدم السماح بإعلانات إنتاجية قبل اعتماد عمر الجمهور والامتثال واللغات النهائية. لا استنتاج أن 13+ قرار نهائي.


## اعتماد واجهات الهوية والمزامنة Q22–Q27
- المصادقة في Flutter: Google على Android/iOS فقط + Email/Password + Guest. **Apple غير موجود**. Google token يجب التحقق من صحته على Laravel؛ فشل المزود لا يمس تقدم الضيف.
- OTP متعدد السياقات في نفس الواجهة: توثيق بريد/استعادة كلمة مرور/دخول إجباري بعد 5 إخفاقات؛ Hash للرمز وقفل عمليات وإبطال الكود القديم، ومحددات resend حسب الحساب والجهاز والشبكة.
- قبل توثيق البريد: بدء اللعب مسموح لكن مزامنة الأجهزة ومكافآت الهوية Pending؛ هذا لا يمنح للعميل حق خصم أو اعتماد مكافأة.
- Smart Merge: Snapshot للسجلين، union للأرصدة المعرفية وأفضل نتائج صحيحة؛ Ledger مسجل مصدر نهائي، ومعاملة idempotent بمفتاح guest_identity + target_account لمنع منح مضاعف. الواجهة الموجودة رقم29 تعرض Confirm/Retry.
- Offline-First: Event IDs ثابتة + local journal + retry idempotent؛ خادم يتأكد من صحة المحاولات، wallet server-authoritative، Pending لا تُصرف؛ Booster Offline فقط من رصيد محجوز مسبقًا.
- Preferred World: قيمة تفضيل لا تغير فتح عالم أو تكلفة، والحسم لآخر حفظ ناجح في الخادم.
- API contracts عند البرمجة تعكس هذه السياسات فقط؛ **لم ينشأ مشروع Laravel ولا API فعلية داخل حزمة التصميم**.

## إضافة تصميم خدمة Inbox وPush والجدولة — لا كود تشغيل

**واجهة الإدارة:** ADM12 تتيح مسودة AR/EN، اختيار أحد أنواع Q36، وجهة داخل شاشة لاعب قائمة، معاينة Android/iOS، إرسال الآن أو جدولة واحدة UTC، فحص الأهلية والموافقة، إلغاء قبل Dispatch، عرض حالات الخطأ والسجل. لا نقول إن قبول مزود Push يعني وصوله للمستخدم.

**تصميم البيانات المبدئي:** `notification_messages` (مرجع ثابت/نوع/نسختا النص/الهدف)، `notification_schedules` (محرر/وقت UTC/حالة/تاريخ إلغاء)، `notification_deliveries` (مستلم/محاولة/نتيجة مزود/مفتاح منع التكرار)، `inbox_messages` (قابل للقراءة/مدة احتفاظ/رابط وجهة مسموح)، `device_push_tokens` (ملكية الحساب/المنصة/تاريخ التدوير، مشفر وحساس)، و`user_notification_preferences` منفصلة عن جدول `consent_versions`. هذه كيانات *تصميم معماري* لا migrations ولا قاعدة منشأة.

**Laravel على cPanel:** Cron/Queue worker مناسب أو بديل مُثبت حيث تمنع Shared Hosting عمليات طويلة؛ جدولة بمعاملات مقفلة لمنع العمل المتزامن، وإعادة تحقق من التفضيلات الحالية والحساب والسن/المنطقة والوجهة عند الإرسال، وRetry بمفتاح ثابت، مع سجلات مراجعة دون تسريب بيانات شخصية؛ قِس واجهة الجهاز على iOS وAndroid. لا تضع مفاتيح مزود Push في حزمة التصميم/الإصدار العامة.

**الخصوصية:** التسويق OFF افتراضيًا وممنوع دون Opt-in مستقل، أحداث V1 غير مفعلة، نصوص القفل عامة بدون بريد أو OTP، الرسائل الأمنية يمكن تسجيلها بـInbox حتى عند إيقاف Push إذا كان ذلك مشروعًا ووفق القوانين.

**المخاطر المفتوحة بعد الموافقات النهائية:** Q40 الفني/أجهزة صغيرة، Android adaptive icon، موافقة قانونية، وإثبات استقبال الدعم وتشغيل Push/SDK وCron؛ قرارات PN01–PN04 وQ39 حُسمت بالفعل، والتسليم يظل تصميمًا دون اختبار تشغيل.

## تحديث سياسة Push/Brand (Q39 وPN01–PN04)
- الهوية الرسمية مستوردة في `00_SHARED/branding/` مع معادلة الأصول في `02_DESIGN/BRAND_INTEGRATION_CONTRACT.json`؛ لا يعاد رسم شعار النص.
- سجل الجدولة يعرّف وقتًا محليًا لكل لاعب وفق IANA؛ لكل موعد مستلم نتيجة UTC قابلة لإعادة الاحتساب عند تغيير timezone. لا تضبط Fixed UTC للجميع كبديل.
- Laravel Scheduler/Queue (لاحقًا عند التطوير) يفحص قبل الإرسال `active event`, الموافقة/إذن OS، de-dup، الحد 2 normal / rolling 24h، والسكون 22–08 حسب منطقتهم. الأمان الحرج فقط مستثنى، دون بيانات حساسة داخل Payload.
- عند تعطّل Cron: الإرسال العادي المتأخر يظل مؤهلًا 6 ساعات فقط إذا لم تنته صلاحيته ولم تتجاوز ساعات الصمت المهلة. تبقى رسائل Inbox مستقلة. لا ترسل موجة قديمة عقب العودة.
- الرسائل التسويقية غير متاحة في V1؛ جدولة Events تتطلب نشر حدث حقيقي.
- معيار التسليم المستقبلي Laravel: ONE ZIP → WEB INSTALLER → ADMIN SIGNED ZIP UPDATES، Backup/Recovery وCI Fresh Install/Upgrade؛ هنا عقود **تصميم** فقط.

## تخطيط ربط Firebase والموبايل (تصميم، دون كود)
- استخدم ملفي Android/iOS العميلين المرفقين في بناء Flutter لاحقًا بعد التأكد من الهوية والتوقيعات.
- خادم Laravel يرسل بواسطة FCM HTTP v1 ببيانات اعتماد **خارج حزمة التصميم** ومحمية في البيئة؛ Firebase تتكامل مع APNs على iOS بعد إعداد مفتاح Apple الخاص والـCapabilities في حساب المطور.
- لا توضع مفاتيح خدمة Firebase/APNs في DB غير مشفرة أو ملفات ZIP العامة، ولا تخزن رموز أجهزة المستخدمين في ملف manifest.
- تواصل Queue/Scheduler بتنفيذ PN01–PN04، وحفظ Pending/Sent-to-provider مستقل عن Delivered/Opened.
- تنفيذ شاشات الإعدادات الموثقة في `04_BACKEND_DESIGN/13_System_Settings` داخل نفس Settings المحمية بصلاحيات Super Admin، مع Audit والاختبارات، دون إنشاء منتجات أخرى.
