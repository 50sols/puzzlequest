import 'package:flutter/material.dart';
import '../core/theme.dart';

/// Purely visual styling. World availability always comes from the server
/// catalog and never from a color, image, or animation.
@immutable
class PQWorldCardLighting {
  const PQWorldCardLighting._();

  static const radius = BorderRadius.all(Radius.circular(20));

  static BoxDecoration outer(Color accent, {required bool available}) =>
      BoxDecoration(
        borderRadius: radius,
        boxShadow: available
            ? [
                BoxShadow(
                  color: accent.withValues(alpha: .84),
                  blurRadius: 30,
                  spreadRadius: 3,
                ),
                BoxShadow(
                  color: PQColors.gold.withValues(alpha: .43),
                  blurRadius: 16,
                  spreadRadius: 1,
                ),
                const BoxShadow(
                  color: Color(0x88000000),
                  blurRadius: 10,
                  offset: Offset(0, 5),
                ),
              ]
            : const [
                BoxShadow(
                  color: Color(0x66000000),
                  blurRadius: 7,
                  offset: Offset(0, 3),
                ),
              ],
      );

  static BorderSide rim(Color accent, {required bool available}) => BorderSide(
        color: available ? PQColors.gold : const Color(0xFF565071),
        width: available ? 3 : 1.5,
      );

  static LinearGradient scrim({required bool available}) => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: available
            ? const [
                Color(0x33FFFFFF),
                Color(0x006F48F1),
                Color(0xD7131030),
              ]
            : const [
                Color(0xA8131030),
                Color(0xB4131030),
                Color(0xF0131030),
              ],
        stops: const [0, .36, 1],
      );

  static Color? artworkTint({required bool available}) =>
      available ? null : const Color(0xFF8A819B);
}
