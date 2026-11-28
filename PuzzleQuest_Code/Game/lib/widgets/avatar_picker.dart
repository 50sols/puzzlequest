import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Exact avatar IDs accepted by Laravel's account/profile endpoint.
class PuzzleAvatar {
  const PuzzleAvatar(this.id, this.ar, this.en);
  final String id, ar, en;
  String get asset => 'assets/design/art/characters/avatars/$id.png';
}

const puzzleAvatars = <PuzzleAvatar>[
  PuzzleAvatar('explorer_boy_blue', 'المغامر الأزرق', 'Blue Explorer'),
  PuzzleAvatar('explorer_boy_glasses', 'المغامر بالنظارة', 'Goggle Explorer'),
  PuzzleAvatar('explorer_elder_scout', 'الكشاف الحكيم', 'Wise Scout'),
  PuzzleAvatar('explorer_elder_turquoise', 'المستكشف الفيروزي', 'Turquoise Explorer'),
  PuzzleAvatar('explorer_girl_orange', 'المغامرة البرتقالية', 'Orange Explorer'),
  PuzzleAvatar('explorer_girl_purple', 'المغامرة البنفسجية', 'Purple Explorer'),
  PuzzleAvatar('explorer_man_orange', 'المغامر البرتقالي', 'Orange Adventurer'),
  PuzzleAvatar('explorer_woman_yellow', 'المغامرة الذهبية', 'Golden Adventurer'),
];

/// Images are bundled with the game: this selector works without any API.
class PuzzleAvatarPicker extends StatelessWidget {
  const PuzzleAvatarPicker({
    super.key, required this.selectedId, required this.arabic,
    required this.onSelected,
  });
  final String? selectedId;
  final bool arabic;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) => GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: puzzleAvatars.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12,
        childAspectRatio: .91,
      ),
      itemBuilder: (context, index) {
        final avatar = puzzleAvatars[index];
        final selected = avatar.id == selectedId;
        final label = arabic ? avatar.ar : avatar.en;
        return Semantics(
          button: true, selected: selected,
          label: '${arabic ? 'اختر' : 'Select'} $label',
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              key: ValueKey('avatar-${avatar.id}'),
              onTap: () => onSelected(avatar.id),
              borderRadius: BorderRadius.circular(22),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 170),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter, end: Alignment.bottomCenter,
                    colors: selected
                      ? const [Color(0xFF6842B4), Color(0xFF2D2058)]
                      : const [Color(0xFF382764), Color(0xFF211D47)],
                  ),
                  borderRadius: BorderRadius.circular(22),
                  border: Border.all(
                    color: selected ? PQColors.gold : const Color(0xFF655A8A),
                    width: selected ? 2.5 : 1.2,
                  ),
                  boxShadow: selected ? const [
                    BoxShadow(color: Color(0x66FFBB31), blurRadius: 18),
                  ] : const [],
                ),
                child: Column(children: [
                  Expanded(child: Stack(children: [
                    Center(child: ClipOval(child: Container(
                      width: 112, height: 112,
                      color: const Color(0xFF241747),
                      child: Image.asset(
                        avatar.asset, fit: BoxFit.cover,
                        errorBuilder: (_, __, ___) => const Icon(
                          Icons.person_rounded, color: PQColors.gold, size: 66),
                      ),
                    ))),
                    if (selected) const PositionedDirectional(
                      top: 2, end: 2,
                      child: Icon(Icons.check_circle_rounded,
                        color: PQColors.gold, size: 26)),
                  ])),
                  const SizedBox(height: 5),
                  Text(label, maxLines: 1, overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: selected ? PQColors.gold : PQColors.white,
                      fontSize: 13, fontWeight: FontWeight.w700)),
                ]),
              ),
            ),
          ),
        );
      },
    ),
  );
}
