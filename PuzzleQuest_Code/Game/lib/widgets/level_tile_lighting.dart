import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Visual-only contrast between server-unlocked, completed and locked levels.
/// Never use this decoration to infer or grant gameplay access.
@immutable
class PQLevelTileLighting {
  const PQLevelTileLighting({
    required this.outer,
    required this.face,
    required this.iconColor,
    required this.textShadows,
  });

  final BoxDecoration outer;
  final BoxDecoration face;
  final Color iconColor;
  final List<Shadow> textShadows;

  static const radius = BorderRadius.all(Radius.circular(16));

  static PQLevelTileLighting forState({
    required bool playable,
    required bool completed,
  }) {
    if (completed) {
      return PQLevelTileLighting(
        outer: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: PQColors.success.withValues(alpha: .38),
              blurRadius: 15,
              spreadRadius: 1,
            ),
            const BoxShadow(
              color: Color(0x88000000),
              blurRadius: 7,
              offset: Offset(0, 3),
            ),
          ],
        ),
        face: const BoxDecoration(
          borderRadius: radius,
          border: Border.fromBorderSide(
            BorderSide(color: Color(0xFFAEFF87), width: 2),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFF73E941),
              Color(0xFF2B9730),
              Color(0xFF17481F),
            ],
            stops: [0, .43, 1],
          ),
        ),
        iconColor: PQColors.gold,
        textShadows: const [
          Shadow(color: Color(0xBB153F17), blurRadius: 5),
        ],
      );
    }
    if (playable) {
      return PQLevelTileLighting(
        outer: BoxDecoration(
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: PQColors.purple.withValues(alpha: .82),
              blurRadius: 22,
              spreadRadius: 1.5,
            ),
            BoxShadow(
              color: PQColors.gold.withValues(alpha: .52),
              blurRadius: 9,
              spreadRadius: .5,
            ),
            const BoxShadow(
              color: Color(0x88000000),
              blurRadius: 6,
              offset: Offset(0, 3),
            ),
          ],
        ),
        face: const BoxDecoration(
          borderRadius: radius,
          border: Border.fromBorderSide(
            BorderSide(color: PQColors.gold, width: 2.5),
          ),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color(0xFFF19CFF),
              Color(0xFFAB46EF),
              Color(0xFF6928C7),
            ],
            stops: [0, .4, 1],
          ),
        ),
        iconColor: PQColors.gold,
        textShadows: const [
          Shadow(color: Color(0xCC421471), blurRadius: 5),
          Shadow(color: Color(0x99FFF1B1), blurRadius: 12),
        ],
      );
    }
    return const PQLevelTileLighting(
      outer: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(color: Color(0x55000000), blurRadius: 5, offset: Offset(0, 2)),
        ],
      ),
      face: BoxDecoration(
        borderRadius: radius,
        border: Border.fromBorderSide(
          BorderSide(color: Color(0xFF534C78), width: 1.5),
        ),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF393354),
            Color(0xFF211D39),
          ],
        ),
      ),
      iconColor: PQColors.muted,
      textShadows: [],
    );
  }
}
