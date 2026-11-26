# 07_Level_Complete

- الاكتمال المحلي يعرض «اكتملت الصورة — المكافأة قيد المزامنة» حتى التأكيد.
- بعد التأكيد تظهر القيمة الفعلية؛ الضغط المتكرر أو إعادة الدخول لا يعيد منح المكافأة.

Next يفتح المستوى التالي فقط إذا كان موجودًا ومتاحًا؛ وإلا يعود لقائمة المراحل. Replay يبدأ نفس المستوى والصعوبة بعد تأكيد إعادة البدء؛ لا يعيد منح استحقاق سبق تأكيده.

- DESIGN.json المرجع السلوكي وربط الأصول، و LAYOUT.svg مخطط نهائي قابل للتعديل لنفس المكونات الموجودة.
- مستطيلات rect_dp فوق مساحة محتوى 390×844 بعد المساحات الآمنة، وليست إحداثيات شاشة 1080px. المقاسات الأخرى تعيد التدفق وفق ../../02_DESIGN/RESPONSIVE_AR.md.
- reference.png مرجع الفن والنطاق المرئي، ولا تُعرض كشاشة تفاعلية. مسارها الفعلي في DESIGN.json.
- النصوص الحية: ../../02_DESIGN/COPY_AR.json و COPY_EN.json؛ حالات المكونات: COMPONENTS.json.
- لا أسعار أو مكافآت أو خدمة جديدة تُستنتج من الرسم. العناصر visible_in_source_requires_details موجودة بالصورة لكنها تحتاج تفصيلًا قبل تنفيذها؛ لا تنشئ لها شاشات من عندك.

## قرارات Q01–Q12 المعتمدة
- مصدر السلوك والأرقام المعتمد: `../../02_DESIGN/APPROVED_PRODUCT_RULES.json`، والأقسام المعنية بهذه الشاشة: `rating, first_completion_reward`.
- الصور المرجعية تمثل التكوين البصري فقط؛ لا تكرر رقم مرحلة 12 أو 36/45 أو رصيد تجريبي من screenshot. التقدم والرصيد من مصدر البيانات المعتمد، والإشارات المعلقة لا تتحول إلى أفعال تلقائية.

## اعتماد Q13–Q21 — الربط الحي

first completion confirmed +500 Coins and star delta; repeat +0 Coins, only positive star improvement; no Gems or phantom collection currency المرجع الحاكم `../../02_DESIGN/APPROVED_PRODUCT_RULES.json`، ومراحل جديدة متوافقة عبر `../../02_DESIGN/CONTENT_PUBLISHING_CONTRACT.json` دون تحديث التطبيق. الأرقام والـGems في صورة المرجع تاريخية وليست نصًا حيًا أو مكافأة. لقطات المراجعة محفوظة دون تعديل.

## اعتماد Q13–Q21 — الربط الحي

first completion confirmed +500 Coins and star delta; repeat +0 Coins, only positive star improvement; no Gems or phantom collection currency المرجع الحاكم `../../02_DESIGN/APPROVED_PRODUCT_RULES.json`، ومراحل جديدة متوافقة عبر `../../02_DESIGN/CONTENT_PUBLISHING_CONTRACT.json` دون تحديث التطبيق. الأرقام والـGems في صورة المرجع تاريخية وليست نصًا حيًا أو مكافأة. لقطات المراجعة محفوظة دون تعديل.
