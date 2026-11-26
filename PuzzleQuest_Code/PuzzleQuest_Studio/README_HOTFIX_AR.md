# PuzzleQuest Studio v1.1.2 — إصلاح صيغة ZIP حسب أصول اللعبة المنشورة

يصلح التصدير المحلي بحيث يحتوي ZIP على الملفات في الجذر: `level.json` و`manifest.json` و`master.png`، ومجلدي `36_pieces` و`36_masks_svg` إذا اخترت 36 قطعة (وتتغير البادئة وفق العدد).

فك الضغط **داخل مجلد برنامج PuzzleQuest Studio الحالي**، بحيث يصبح مسار الملف `puzzlequest_studio/laravel_import.py` في مكانه الصحيح. وافق على استبدال الملفات ثم شغّل `launch_windows.bat`. لا ترفع ملف QuickFix هذا إلى الداشبورد؛ هو تحديث لبرنامج Windows فقط.

اختبر الباكدج من زر Verify an existing ZIP أولًا، ثم ارفعه عبر Online Manager أو الداشبورد. لا تنشره إلا بعد QA على الأجهزة. الإصدار السابق قد يكون منشورًا بالفعل؛ لا تحذف الملفات أو مراجعاته.
