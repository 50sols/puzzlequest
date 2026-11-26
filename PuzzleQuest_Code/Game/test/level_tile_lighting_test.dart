import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzlequest_game/core/theme.dart';
import 'package:puzzlequest_game/widgets/level_tile_lighting.dart';

void main() {
  group('Level grid lighting', () {
    test('available level has stronger bloom and gold rim than locked', () {
      final available = PQLevelTileLighting.forState(
        playable: true, completed: false);
      final locked = PQLevelTileLighting.forState(
        playable: false, completed: false);

      final availableBloom = available.outer.boxShadow!.first;
      final lockedShadow = locked.outer.boxShadow!.first;

      expect(availableBloom.blurRadius, greaterThan(lockedShadow.blurRadius));
      expect(availableBloom.color.a, greaterThan(lockedShadow.color.a));
      expect(available.face.border!.top.color, PQColors.gold);
      expect(locked.face.border!.top.color, isNot(PQColors.gold));
      expect(available.iconColor, PQColors.gold);
      expect(available.textShadows, isNotEmpty);
      expect(locked.textShadows, isEmpty);
    });

    test('completed levels retain readable success lighting', () {
      final completed = PQLevelTileLighting.forState(
        playable: true, completed: true);
      final available = PQLevelTileLighting.forState(
        playable: true, completed: false);
      final locked = PQLevelTileLighting.forState(
        playable: false, completed: false);

      expect(completed.outer.boxShadow!.first.blurRadius,
          greaterThan(locked.outer.boxShadow!.first.blurRadius));
      expect(completed.outer.boxShadow!.first.blurRadius,
          lessThan(available.outer.boxShadow!.first.blurRadius));
      expect((completed.face.gradient as LinearGradient).colors.first,
          isNot((locked.face.gradient as LinearGradient).colors.first));
    });

    testWidgets('all lighting modes paint within the same compact tile size', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(body: Center(child: SizedBox(
          width: 320, height: 96,
          child: Row(children: [
            for (final state in [(true, false), (true, true), (false, false)])
              Expanded(child: Padding(
                padding: const EdgeInsets.all(6),
                child: DecoratedBox(
                  decoration: PQLevelTileLighting.forState(
                    playable: state.$1, completed: state.$2).outer,
                  child: DecoratedBox(
                    decoration: PQLevelTileLighting.forState(
                      playable: state.$1, completed: state.$2).face,
                    child: const Center(child: Text('1')),
                  ),
                ),
              )),
          ]),
        ))),
      ));
      expect(tester.takeException(), isNull);
      expect(find.text('1'), findsNWidgets(3));
    });
  });
}
