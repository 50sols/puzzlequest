import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzlequest_game/core/theme.dart';
import 'package:puzzlequest_game/widgets/puzzle_dialog.dart';

void main() {
  for(final arabic in [false,true]) {
    testWidgets('Fantasy popup supports long content and actions, Arabic: $arabic',(tester) async {
      tester.view.physicalSize=const Size(390,844);
      tester.view.devicePixelRatio=1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      var confirmed=false;
      final key=GlobalKey();
      await tester.pumpWidget(MaterialApp(theme:puzzleTheme(arabic),home:RepaintBoundary(
        key:key,child:Scaffold(body:Directionality(
          textDirection:arabic?TextDirection.rtl:TextDirection.ltr,
          child:PuzzleDialog(title:Text(arabic?'حدث خطأ':'Something Went Wrong'),
            content:Text(arabic?'حدث خطأ غير متوقع. حاول مرة أخرى.':'An unexpected error occurred. Please try again.'),
            actions:[TextButton(onPressed:(){},child:const Text('Go Back')),
              FilledButton(onPressed:()=>confirmed=true,child:const Text('Try Again'))]),
        )))));
      final context=tester.element(find.byType(PuzzleDialog));
      await tester.runAsync(() async {
        for(final name in ['panel','heading','warning','primary','secondary']) {
          await precacheImage(AssetImage('assets/ui/popups/$name.png'),context);
        }
      });
      await tester.pump();
      expect(tester.takeException(),isNull);
      await tester.tap(find.text('Try Again'));
      expect(confirmed,isTrue);
      if(!arabic) {
        final boundary=key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        await tester.runAsync(() async {
          final image=await boundary.toImage();
          final bytes=await image.toByteData(format:ui.ImageByteFormat.png);
          await File('build/popup_preview.png').writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      }
      tester.view.physicalSize=const Size(320,568);
      await tester.pump();
      expect(tester.takeException(),isNull);
      await tester.ensureVisible(find.text('Try Again'));
      await tester.tap(find.text('Try Again'));
      expect(tester.takeException(),isNull);
    });
  }
}
