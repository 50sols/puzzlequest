# PuzzleQuest — DOC 03 / 08: Component Library & Design Tokens

**وثيقة المرجع:** نص صاحب المشروع «PUZZLEQUEST / DESIGN-TO-DEVELOPMENT HANDOFF — Component Library & Design Tokens»، Spec v1.0، 25 نوفمبر 2026. **الصفة: مواصفة قبل التطوير، وليست دليل تشغيل.**

## مصادر الحوكمة

- الألوان/الخطوط/المسافات والأنصاف والتباينات: `assets/config/design_tokens.approved.v1.json` نسخة **مطابقة بايتًا** من `PuzzleQuest_Design_FINAL/02_DESIGN/DESIGN_TOKENS.json`.
- عقود المكونات: `assets/config/components.approved.v1.json` من `02_DESIGN/COMPONENTS.json`.
- الحركة: `assets/config/motion.approved.v1.json` من `02_DESIGN/MOTION.json`.
- الأزرار الأربعة في 5 حالات: `assets/ui/buttons/` ملفات PNG نفسها التي جاءت من `00_SHARED/ui/buttons/`، دون إعادة رسم أو تعديل.
- تمثيل العقود عمليًا: `lib/core/theme.dart` و`lib/widgets/component_library.dart` و`lib/widgets/pq_widgets.dart`.
- معاينة التطوير (ليست شاشة للاعب): `tool/component_gallery_main.dart`.

## دلالات الألوان

| Token | ARGB في السورس | المرجع المعتمد |
|---|---|---|
| Background | `0xFF131030` | `background` |
| Surface | `0xFF23134A` | `surface` |
| Primary purple | `0xFF8F3DF4` | `primary` |
| Purple | `0xFF7D4DFF` | `purple` |
| Gold | `0xFFFFBB31` | `accent` |
| Success | `0xFF39D45E` | `success` |
| Danger | `0xFFF76B87` | `error` |
| Action green | `0xFF23C41C` | `action_green` |
| Text | `0xFFF7F4FF` | `text` |
| Muted | `0xFFBFB8D6` | `muted_text` |

لا يوجد لون جديد معتمد: `PQColors.panel` alias لـ`surface`. مسافات التصميم المعتمدة 4/8/12/16/24/32 DP، وأنصاف الأقطار 8/14/20/28 DP، واللمس الأدنى 48 DP. مفاتيح مسافات `space.7..8` أو قيم ظلال/شبكات جديدة تتطلب استخراجًا من الصور الأصلية وليس تخمينًا.

## تعارض الخط الإنجليزي بين المراجع

نص **DOC 03** الذي أرسله المالك ينص على **Nunito**، بينما `DESIGN_TOKENS.json` و`BRAND_INTEGRATION_CONTRACT.json` داخل الحزمة النهائية المعتمدة ينصان صراحةً على **Lato** وأن تعليمات Nunito القديمة نُسخت بقرار صاحب المشروع. حفاظًا على النسخة المعتمدة وعدم إدخال خط جديد دون ملف وموافقة، يستخدم التطبيق **Lato** للإنجليزية و**Tajawal** للعربية. **الحسم الجديد من المالك مطلوب قبل تغيير Lato إلى Nunito.**

## مكونات DOC 03 وحالاتها

ملف `DOC03_COMPONENT_MATRIX.csv` يوضح: 20 عنصرًا أساسيًا، موقع الكود، حالة ربطه بالواجهة الحية، ما يحتاج اختبار حدث/تعطيل، وحالة GATE. المكونات تقدم عرضًا فقط ولا تُصدر عملات/نجوم/ترقيات ولا تزعم نجاح مشاهدة إعلان.

- PrimaryCTA/SecondaryCTA: حالات `normal/pressed/focused/loading/disabled` من صور المصمم. ضغط متكرر أثناء العملية غير مسموح.
- HUDCurrency: حالة `pending` تعرض علامة انتظار، ولا تعرض `0` زائفًا قبل استلام بيانات الخادم.
- HUDTimer: يعرض الزمن المتبقي من Stopwatch الموجود؛ توقف/خلفية/انتهاء وقت محكوم بتدفق اللعبة.
- StarRating: لا يُظهر نجومًا مكتسبة حتى تأكيد نتيجة Laravel.
- LevelTile / WorldCard: توافر المرحلة من كتالوج Laravel، والعوالم المستقبلية مغلقة ما لم تُنشر.
- PuzzlePiece / PuzzleBoard: صور PNG ومراسي الـManifest الأصلية دون استبدال؛ اختبارات polygon/alpha والدقة البصرية للمستوى 100 قطعة ما زالت GATE.
- WalletPurchase / RewardDialog / AdChoice / MissionRow / BuildingCard: UI بحالات لا تتجاوز التحقق أو الصلاحيات الخادمية.
- TrophyBadge / LanguageSwitcher / NotificationTile / InlineStatus / ConfirmationSheet: مكونات ذات تسميات وإشارات حالة وإجراءات مقيدة.

## الحركة وإمكانية الوصول

مدد المصدر المعتمد: Pickup 110ms، Near target 130ms، Snap 170ms، Wrong drop 190ms، Win 650ms، Restore 500ms. إنقاص الحركة يلغي انتقال قطعة التحديد، ومنفصل عن تفضيلات الصوت والاهتزاز؛ هذه التفضيلات لا تغير حساب الوقت أو النجوم أو الاقتصاد. صوت الضغط الافتراضي للنظام تم توصيله لمواضع التثبيت، وليس نظام أصوات احترافيًا معتمدًا.

الأزرار تستعمل `Semantics` وتسميات، حد اللمس ≥48 DP، والنصوص العربية والإنجليزية تبني RTL/LTR حسب اللغة. **اختبارات golden البصرية/التركيز مع قارئ الشاشة/أجهزة بعرض ضيق وتكبير النص لم تجتز بعد** ولا يجوز تقريرها من الفحص الساكن.

## موانع إصدار Production وفق تعريف DONE

1. موافقة مالك المنتج على Pixel/asset mapping مع مقارنة صور AR/EN الحقيقية.
2. `flutter analyze` و`flutter test` لـv1.2.0 (بما فيها اختبارات المكوّنات) على Mac؛ ثم Android APK/AAB وiOS Simulator/Physical.
3. اختبارات موجّهة لجميع حالات المكوّنات وضغط زرّين وتبريد الخادم وRTL وعرض ضيق ووضع Reduce Motion.
4. جولة كاملة على 100 قطعة، Alpha/Polygon masking ودقة الصورة ومناطق اللمس وأداء Flame.
5. اعتماد مستندات الموافقات القانونية على Backend، وتوثيق OAuth/AdMob SSV/FCM/APNs وإغلاق بوابات الحساب وPush.

**لا يُعتبر نجاح بنية السورس أو سلامة ZIP موافقة إطلاق.**
