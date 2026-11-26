import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzlequest_game/core/session.dart';
import 'package:puzzlequest_game/core/theme.dart';
import 'package:puzzlequest_game/screens/screens.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('plugins.flutter.io/google_mobile_ads'),
        (call) async => null);
  });
  for (final width in [320.0, 390.0]) {
    for (final arabic in [false, true]) {
      testWidgets('Home paints bundled artwork at $width, Arabic: $arabic', (tester) async {
        tester.view.physicalSize = Size(width, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        final session = PuzzleSession()..arabic = arabic;
        await tester.pumpWidget(MaterialApp(theme: puzzleTheme(arabic),
          home: Directionality(textDirection: arabic ? TextDirection.rtl : TextDirection.ltr,
            child: ScreenPage(session: session, id: 2))));
        final context = tester.element(find.byType(ScreenPage));
        final providers = tester.widgetList<Image>(find.byType(Image))
            .map((image) => image.image).toList();
        await tester.runAsync(() async {
          for (final provider in providers) {
            await precacheImage(provider, context);
          }
        });
        await tester.pump();
        expect(tester.takeException(), isNull);
        final title = find.text(arabic ? 'رمّم قريتك' : 'Rebuild Your Village');
        expect(tester.getSize(title).width, greaterThan(150));
        await tester.pumpWidget(const SizedBox());
        session.dispose();
      });
    }
  }
}
