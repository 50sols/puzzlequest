# PuzzleQuest Studio v1.1.2 — Exact asset manifest format

التصدير الجديد المطابق للمجلد المرجعي يحتوي مباشرةً على `manifest.json` و`level.json` و`master.png` ومجلدي `<N>_pieces` و`<N>_masks_svg`، مع تسمية `piece_000`. عند 36 قطعة: الخلية 160 بكسل، الهامش 44، وحد Snap هو 35.

وجود `level.json` إلزامي لاستيراد الداشبورد، حتى لو لم يظهر في صورة الأصول المنشورة. لا تستبدل إصدارًا منشورًا؛ استخدم Revision جديدًا بعد فحص الجودة. تعديل بنية ZIP لا يعالج مسار تخزين Laravel على الخادم.

# PuzzleQuest Studio v1.0.9 — عقد Laravel الحقيقي

## تم استخراج القواعد من `app.rar`
المصدر: `app/Services/Content.php` (دوال `import` و`validate`) و`app/Services/SafeZip.php`، المرفوعان بواسطة مالك المشروع يوم 26 نوفمبر 2026.

### حقول `level.json` الإلزامية (في الجذر، ليست داخل `metadata`)

| اسم الحقل | النوع | المثال |
|---|---|---|
| `level_id` | نص `[a-z0-9_]{3,100}` | `level_006_green_valley` |
| `world_id` | نص موجود فعلًا في جدول `worlds.id` | `green-valley` **غير مؤكد** |
| `display_code` | نص `[0-9]+-[0-9]+` | `1-6` |
| `position` | integer >= 1 | `6` |
| `title` | كائن يحتوي `ar` و`en` غير فارغين | `{"ar":"طاحونة الوادي الأخضر","en":"Green Valley Watermill"}` |
| `piece_count` | integer من `16,36,64,100` | `100` |
| `level_time_limit_seconds` | integer | `1800` |
| `three_star_seconds` | integer | `900` |
| `two_star_seconds` | integer | `1440` |

تسلسل الوقت: `0 < three_star_seconds <= two_star_seconds <= level_time_limit_seconds <= 7200`.

**فرق جوهري:** `level_id` ليس `1-6` — هذا `display_code`. سيتم اشتقاق `level_006_green_valley` تلقائيًا عند ترك حقل Server level ID فارغًا. عند تحديث مرحلة موجودة يجب استخدام معرّفها الفعلي في الداشبورد، لأن الهوية `world_id` و`display_code` تصبح ثابتة.

`previous_level_id` اختياري. المثال يتصل بالمرحلة الخامسة ذات المعرف المرصود في واجهة الإدارة: `level_005_autumn_tree`.

### عقد `manifest.json`
- `schema_version`: `"1.0.0"`
- `level_id`: يطابق حرفيًا `level.json.level_id`.
- `board_size_px`: `[960,960]` بالضبط.
- `difficulty_piece_count`: مطابق لعدد القطع.
- `grid.rows` و`grid.columns`: 4/6/8/10 بحسب العدد.
- `padding_px`: عدد صحيح >=0 و <= طول الخلية.
- `snap_threshold_board_px`: رقم أكبر من صفر وأصغر أو يساوي نصف طول الخلية.
- `master_image_path`: ملف PNG فعلي بأبعاد 960×960.
- `pieces`: مصفوفة تحتوي عدد القطع بالضبط. كل عنصر يضم `id`, `row`, `column`, `snap_anchor_px`, `target_rect_px`, `image_path` بصيغة PNG, `mask_path` بصيغة SVG, `edges` للقيم `top/right/bottom/left` من {-1,0,1}. يجب أن تتكامل الحواف ويُغطى كامل سطح الصورة دون ثقوب.

### قيود ZIP الفعلية
- `level.json` و`manifest.json` في جذر ZIP.
- الملفات المسموحة: `json,png,jpg,jpeg,webp,svg` فقط.
- أقصى 1500 مدخل وأقصى حجم غير مضغوط 128 MiB، مع منع الأسماء المكررة والمسارات الخطرة والروابط الرمزية وحزم الضغط المفرط.
- يجب أن تمر PNG وSVG والسجل الهندسي من مدقق Content.php قبل إنشاء `ready` revision.
- النشر مرحلة منفصلة: يتطلب Device QA موافقًا عليه داخل الداشبورد.

## تشغيل Windows
افتح `launch_windows.bat`. يكتشف Python ويثبت Pillow وNumPy في بيئة المشروع إن لزم. يشترط اتصال إنترنت لأول تثبيت للتبعيات. لا تحتاج كتابة أوامر.

**الحقول المطلوبة منك في الواجهة:**
1. صورة المرحلة.
2. World ID بالضبط كما يظهر في **العوالم والمراحل** (`/admin/module/2`) — لا تفترض أن `green-valley` هو الـID الفعلي.
3. `Display Code` مثل `1-6` وترتيبه 6.
4. عنوان عربي + إنجليزي والعدد والوقت.
5. `Server level_id` اختياري للمرحلة الجديدة (اشتقاق تلقائي)، لكن يجب إدخاله إذا أردت الاستمرار على هوية مرحلة موجودة.

ثم اضغط Generate & Verify، وارفع ملف `PuzzleQuest-Laravel-...zip` الناتج وحده من صفحة **نشر أصول المراحل**.

## ما تم التحقق منه وما لا يمكن التحقق منه هنا
- تم فحص الباكدج محليًا بالتحقق من حدود ZIP، البنية، القطع، أقنعة SVG، الحواف، غياب الثقوب، لون البكسلات والأعداد ومطابقة الميتاداتا.
- تم تمرير `level.json` و`manifest.json` إلى دالة PHP **نفسها** من `Content.php` عبر Stub لوجود `world_id`: اجتاز الشروط حتى وصل إلى "GD required for content pixel validation". بيئة PHP المحلية لا تحتوي GD، لذلك **لم يُنفذ فحص GD الحقيقي**.
- لا نعرف حاليًا `worlds.id` الحقيقي في قاعدة بيانات الاستضافة، ولا صلاحيات/امتدادات PHP أو الأداء أو نتيجة الرفع، لذلك **لا نعتبر القبول على سيرفر الإنتاج مثبتًا**.
- الـUUID في ZIP محلي؛ السيرفر ينشئ `content_revisions.id` جديدًا عند الاستيراد ويحسب `revision` من SHA-256 لمحتوى `manifest.json` و`level.json`.

## الملفات
- `puzzlequest_studio/laravel_import.py`: مولّد Laravel وQuality Gate الجديد.
- `puzzlequest_studio/builder.py`: المولّد السابق محفوظ للتوافق.
- `tests/test_laravel_import_contract.py`: اختبارات الكود الجديد.
- `docs/LARAVEL_CONTENT_IMPORT_CONTRACT.json`: عقد الآلة مستخرج من PHP.
- `examples/`: باكدج المرحلة السادسة 100 قطعة لاختبار الرفع **بعد التأكد من world_id**.
