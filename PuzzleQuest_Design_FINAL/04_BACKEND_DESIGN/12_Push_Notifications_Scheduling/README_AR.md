# ADM12 — تصميم إدارة الإشعارات والجدولة (بدون كود)

هذه شاشة **Backend Admin** جديدة مطلوبة صراحةً لتصميم Push Notifications والجدولة؛ عدد شاشات اللاعب يبقى 40.

## الملفات
- `LAYOUT.svg` + `PREVIEW.png`: القائمة والحالات والإحصاءات ذات القيم الفارغة.
- `COMPOSE_SCHEDULE.svg` + `COMPOSE_SCHEDULE_PREVIEW.png`: محرر الرسائل العربي/الإنجليزي، الوجهة، اختيار الإرسال الآن أو جدولة مرة واحدة بحسب توقيت كل لاعب المحلي وتخزين وقت التنفيذ UTC، ومعاينة نظام التشغيل.
- `DELIVERY_STATES.svg` + `DELIVERY_STATES_PREVIEW.png`: سجلات المحاولة، تمييز قبول مزود الخدمة عن وصول الجهاز وعن فتح الرسالة.
- `DESIGN.json`: التفاعلات والقيود والتبعيات.

## الإجراءات
Draft → Validate (translations, authorizations, existing destination and eligibility) → Send now / Schedule local/IANA → UTC → Dispatch → provider acknowledgement / error. Cancellation before dispatch; retries idempotent with stable recipient/message key. No promotional pushes without explicit opt-in and regional legal review. Events remain disabled at launch.

UI is illustrative design only, with no running queue, transport or scheduling. To implement on cPanel, verify cron/background worker support or a supported queue/scheduler alternative; do not claim the scheduler is operational.

**تم تضمين الأيقونة الرسمية من حزمة Q39؛ أيقونة النظام الحقيقية تتحدد من البناء المثبت وتحتاج اختبار جهاز.**

## PN01–PN04 معتمد
- الأنواع القائمة فقط، لا حملات تسويق في V1؛ Events لا ترسل ما لم يُنشر حدث فعلي.
- إشعاران عاديان بحد أقصى **خلال 24 ساعة متحركة**؛ الأمن الحرج فقط مستثنى. فترة صمت 22:00–08:00 لكل لاعب بحسب IANA Zone.
- المحرر يعرض اختيار وقت اللاعب المحلي؛ Backend يحتفظ بـUTC لكل إرسال. إذا لم تتحدد المنطقة الزمنية، Inbox يعمل لكن لا يرسل جدولة عادية.
- الإرسال العادي المتأخر متاح لمدة 6 ساعات فقط من موعده الأصلي مع إعادة فحص صلاحية الحدث والهدوء والسقف؛ الإشعارات الملغاة تبقى في Inbox إن ظلت ذات معنى.
- لا يثبت أي رسم تسليم FCM/APNs، ولا نتائج تشغيل scheduler أو ظهور الأيقونة النظامية.
