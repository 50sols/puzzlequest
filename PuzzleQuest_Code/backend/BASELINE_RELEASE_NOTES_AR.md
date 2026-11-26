# PuzzleQuest — Clean First Install Baseline v1.0.0

- أول إصدار تثبيت نظيف جديد من المصدر الحالي، **وليس Update للموقع السابق**.
- يشمل Laravel Studio Remote API, Content Import, Admin, installer, vendor, seed data, content preview, backup/recovery logic.
- اعتماد cPanel fixed-subdomain:
  - private Laravel: /home/solscool/puzzlequest_app
  - document root: /home/solscool/public_html/puzzlequest.50sols.com
  - public_path يربط مباشرة بالدومين الفرعي.
- بناء الباكدج من مصدر backend بعد دمج إصلاحات public path و ContentAssetRelocator و Backups.
- التثبيت: ONE ZIP → Extract مرة من Home → https://puzzlequest.50sols.com/install/ → DB جديدة → Admin.
- تُنشأ خمس مراحل seed أولية حسب المصدر، والمرحلة السادسة تحتاج نشرها لاحقًا عبر Studio.
- يتطلب نجاح التثبيت توافر إضافات PHP و MySQL/cPanel؛ لم يُختبر التثبيت الفعلي على استضافة الإنتاج من هذه البيئة.
- لا يتم تشغيل Workflow أو تغيير قاعدة بيانات الموقع القديم.
