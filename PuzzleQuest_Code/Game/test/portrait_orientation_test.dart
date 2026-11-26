import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzlequest_game/core/orientation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('PuzzleQuest requests portrait-up only, never landscape or upside-down', () async {
    final calls = <MethodCall>[];
    final messenger = TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform,
        (call) async {
          if (call.method == 'SystemChrome.setPreferredOrientations') {
            calls.add(call);
          }
          return null;
        });
    addTearDown(() {
      messenger.setMockMethodCallHandler(SystemChannels.platform, null);
    });

    await lockPuzzleQuestPortrait();

    expect(calls, hasLength(1));
    expect(calls.single.method, 'SystemChrome.setPreferredOrientations');
    expect(calls.single.arguments, <String>['DeviceOrientation.portraitUp']);
  });
}
