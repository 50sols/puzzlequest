import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzlequest_game/core/theme.dart';
import 'package:puzzlequest_game/widgets/world_card_lighting.dart';

void main() {
  const accent = Color(0xFF7D4DFF);

  test('available world uses bright gold rim and strong bloom', () {
    final available = PQWorldCardLighting.outer(accent, available: true);
    final locked = PQWorldCardLighting.outer(accent, available: false);
    expect(available.boxShadow!.first.blurRadius,
        greaterThan(locked.boxShadow!.first.blurRadius));
    expect(available.boxShadow!.length, greaterThan(locked.boxShadow!.length));
    expect(PQWorldCardLighting.rim(accent, available: true).color, PQColors.gold);
    expect(PQWorldCardLighting.rim(accent, available: true).width,
        greaterThan(PQWorldCardLighting.rim(accent, available: false).width));
  });

  test('locked world artwork is subdued without affecting catalog availability', () {
    expect(PQWorldCardLighting.artworkTint(available: true), isNull);
    expect(PQWorldCardLighting.artworkTint(available: false), isNotNull);
    final lit = PQWorldCardLighting.scrim(available: true);
    final dimmed = PQWorldCardLighting.scrim(available: false);
    expect(lit.colors.first.a, lessThan(dimmed.colors.first.a));
    expect(lit.colors.last, isNot(dimmed.colors.last));
  });

  testWidgets('both world states render with identical card footprint',
      (tester) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: Center(
      child: Row(children: [
        for (final unlocked in [true, false])
          Expanded(child: Padding(
            padding: const EdgeInsets.all(8),
            child: DecoratedBox(
              decoration: PQWorldCardLighting.outer(accent, available: unlocked),
              child: SizedBox(height: 120, child: DecoratedBox(
                decoration: BoxDecoration(
                  borderRadius: PQWorldCardLighting.radius,
                  border: Border.fromBorderSide(
                    PQWorldCardLighting.rim(accent, available: unlocked)),
                  gradient: PQWorldCardLighting.scrim(available: unlocked)),
                child: Text(unlocked ? 'Open' : 'Locked'),
              )),
            ),
          )),
      ]),
    ))));
    expect(tester.takeException(), isNull);
    expect(find.text('Open'), findsOneWidget);
    expect(find.text('Locked'), findsOneWidget);
  });
}
