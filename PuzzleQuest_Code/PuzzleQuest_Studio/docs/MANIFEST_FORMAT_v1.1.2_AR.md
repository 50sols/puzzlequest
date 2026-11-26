# PuzzleQuest Studio — صيغة التصدير المعتمدة v1.1.2

```text
PuzzleQuest-Level.zip
  level.json                # REQUIRED BY LARAVEL IMPORTER
  manifest.json             # GAMEPLAY GEOMETRY
  master.png                # 960 x 960 PNG
  36_pieces/
    piece_000.png … piece_035.png
  36_masks_svg/
    piece_000.svg … piece_035.svg
```

الـManifest يطابق تعريف الصورة المرسلة: schema_version=1.0.0، id في كل قطعة piece_000، index يبدأ بصفر، الصف والعمود row_major، والـrect يساوي [column×cell−padding,row×cell−padding,cell+2padding,cell+2padding].

36 قطعة → 6×6 وcell_size_px=160 وpadding_px=44 وsnap_threshold_board_px=35.

لكل عدد N من 16/36/64/100، أسماء المجلدات هي N_pieces وN_masks_svg.

يتم إنتاج هندسة حواف مشتركة مع تناقض القيم على الجوانب المتقابلة، وتوليد Revision UUIDv4. فحص ZIP المحلي لا يثبت نجاح Laravel/MySQL أو عرض Flutter أو التثبيت على cPanel.
