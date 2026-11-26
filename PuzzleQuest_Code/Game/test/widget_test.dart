import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzlequest_game/core/session.dart';
import 'package:puzzlequest_game/main.dart';

void main() {
  test('PuzzleQuest Flutter entrypoint uses the approved application root', () {
    final session = PuzzleSession();
    final app = PuzzleQuestApp(session: session);
    expect(app, isA<StatelessWidget>());
    expect(app.session, same(session));
    session.dispose();
  });
}
