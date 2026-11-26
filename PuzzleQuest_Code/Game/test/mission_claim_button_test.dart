import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzlequest_game/widgets/mission_claim_button.dart';

Widget host(Widget child) => MaterialApp(
  home: Scaffold(body: Center(child: SizedBox(width: 320, child: child))),
);

void main() {
  testWidgets('claim action is always visible but disabled before eligibility',
      (tester) async {
    var claims = 0;
    await tester.pumpWidget(host(PQMissionClaimButton(
      eligible: false, claimed: false, arabic: true,
      onClaim: () => claims++,
    )));
    expect(find.text('أكمل المهمة للتحصيل'), findsOneWidget);
    final disabled = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(disabled.onPressed, isNull);
    await tester.tap(find.byType(FilledButton));
    expect(claims, 0);
    expect(tester.takeException(), isNull);
  });

  testWidgets('only server-eligible and unclaimed mission collects',
      (tester) async {
    var claims = 0;
    await tester.pumpWidget(host(PQMissionClaimButton(
      eligible: true, claimed: false, arabic: true,
      onClaim: () => claims++,
    )));
    expect(find.text('تحصيل المكافأة'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNotNull);
    await tester.tap(find.byType(FilledButton));
    expect(claims, 1);
  });

  testWidgets('already claimed mission displays collected status without action',
      (tester) async {
    var claims = 0;
    await tester.pumpWidget(host(PQMissionClaimButton(
      eligible: true, claimed: true, arabic: false,
      onClaim: () => claims++,
    )));
    expect(find.text('Reward collected'), findsOneWidget);
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    await tester.tap(find.byType(FilledButton));
    expect(claims, 0);
  });

  testWidgets('without callback cannot collect even when eligible',
      (tester) async {
    await tester.pumpWidget(host(const PQMissionClaimButton(
      eligible: true, claimed: false, arabic: false,
    )));
    expect(tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
        isNull);
    expect(tester.takeException(), isNull);
  });
}
