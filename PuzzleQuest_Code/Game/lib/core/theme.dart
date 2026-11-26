import '../widgets/puzzle_dialog.dart';
import 'package:flutter/material.dart';

/// Canonical theme values, transcribed from the owner-approved
/// PuzzleQuest_Design_FINAL/02_DESIGN/DESIGN_TOKENS.json.
/// Never recolor approved raster art to approximate these semantic tokens.
class PQColors {
  static const background = Color(0xFF131030);
  static const surface = Color(0xFF23134A);
  static const primary = Color(0xFF8F3DF4);
  static const purple = Color(0xFF7D4DFF);
  static const gold = Color(0xFFFFBB31);
  static const danger = Color(0xFFF76B87);
  static const success = Color(0xFF39D45E);
  static const actionGreen = Color(0xFF23C41C);
  static const white = Color(0xFFF7F4FF);
  static const muted = Color(0xFFBFB8D6);
  static const panel = surface; // alias of approved surface; no unapproved color
  // Backward-compatible names used by earlier UI widgets.
  static const green = actionGreen;
  static const pink = primary;
}

class PQSpace {
  static const x1=4.0, x2=8.0, x3=12.0, x4=16.0, x5=24.0, x6=32.0;
  static const minTouch=48.0;
  static const gutterPhone=16.0;
}

class PQRadii {
  static const small=8.0, input=14.0, card=20.0, modal=28.0;
}

class PQMotion {
  static const pickup=Duration(milliseconds:110);
  static const nearTarget=Duration(milliseconds:130);
  static const snap=Duration(milliseconds:170);
  static const wrong=Duration(milliseconds:190);
  static const win=Duration(milliseconds:650);
  static const building=Duration(milliseconds:500);
  static Duration resolve(Duration normal,{required bool reduceMotion}) =>
      reduceMotion ? Duration.zero : normal;
}

ThemeData puzzleTheme(bool arabic) {
  final base=ThemeData.dark(useMaterial3:true);
  return base.copyWith(
    scaffoldBackgroundColor:Colors.transparent,
    colorScheme:const ColorScheme.dark(
      primary:PQColors.primary,secondary:PQColors.gold,
      surface:PQColors.surface,onSurface:PQColors.white,
      error:PQColors.danger),
    textTheme:base.textTheme.apply(
      // Final approved source specifies Lato, not draft DOC 03 Nunito.
      fontFamily:arabic?'Tajawal':'Lato',
      bodyColor:PQColors.white,displayColor:PQColors.white),
    dialogTheme: DialogThemeData(
      backgroundColor: PQColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 14,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(24),
        side: const BorderSide(color: Color(0xFF9066DB)),
      ),
      titleTextStyle: TextStyle(color: PQColors.white, fontSize: 22,
        fontFamily: arabic ? 'Tajawal' : 'Lato', fontWeight: FontWeight.bold),
      contentTextStyle: TextStyle(color: PQColors.white, fontSize: 16,
        fontFamily: arabic ? 'Tajawal' : 'Lato'),
    ),
    appBarTheme:const AppBarTheme(
      backgroundColor:PQColors.background,centerTitle:true),
    cardTheme:CardThemeData(color:PQColors.surface,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(PQRadii.card))),
    filledButtonTheme:FilledButtonThemeData(style:FilledButton.styleFrom(
      minimumSize:const Size(PQSpace.minTouch,PQSpace.minTouch),
      backgroundColor:PQColors.actionGreen,
      foregroundColor:PQColors.background,
      shape:RoundedRectangleBorder(borderRadius:BorderRadius.circular(PQRadii.input)))),
    inputDecorationTheme:InputDecorationTheme(filled:true,
      fillColor:PQColors.surface,
      border:OutlineInputBorder(borderRadius:BorderRadius.circular(PQRadii.input))),
  );
}


Future<void> showPuzzleMessage(BuildContext context, String message, {bool warning = false}) async {
  if (!context.mounted || ModalRoute.of(context)?.isCurrent == false) return;
  final arabic = Localizations.localeOf(context).languageCode == 'ar';
  final close = arabic ? 'حسنًا' : 'OK';
  final title = warning ? (arabic ? 'تنبيه' : 'Notice') : 'PuzzleQuest';
  await showDialog<void>(context: context, builder: (dialog) => PuzzleDialog(
    art:message.toLowerCase().contains('server') || message.contains('الخادم')
      ? PuzzleDialogArt.server
      : message.toLowerCase().contains('ad ') || message.contains('إعلان')
        ? PuzzleDialogArt.ad_unavailable
        : message.toLowerCase().contains('connect') || message.contains('اتصال')
          ? PuzzleDialogArt.offline : PuzzleDialogArt.warning,
    constraints: const BoxConstraints(maxWidth: 342),
    scrollable: true,
    icon: Icon(warning ? Icons.info_outline_rounded : Icons.extension_rounded,
      color: PQColors.gold, size: 36),
    title: Text(title, textAlign: TextAlign.center),
    content: Text(message, textAlign: TextAlign.center),
    actionsAlignment: MainAxisAlignment.center,
    actions: [
      FilledButton(
        style: FilledButton.styleFrom(backgroundColor: PQColors.gold,
          minimumSize: const Size(132, 48)),
        onPressed: () => Navigator.pop(dialog),
        child: Text(close),
      ),
    ],
  ));
}
