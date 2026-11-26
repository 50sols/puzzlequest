import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puzzlequest_game/core/api.dart';
import 'package:puzzlequest_game/core/models.dart';
import 'package:puzzlequest_game/core/session.dart';
import 'package:puzzlequest_game/core/theme.dart';
import 'package:puzzlequest_game/game/gameplay.dart';
import 'package:flame/game.dart';
import 'package:flame/components.dart';

void main() {
  testWidgets('Gameplay opens a fresh and resumed board', (tester) async {
    final levels = await tester.runAsync(LocalCatalog.load);
    final level = levels!.first;
    for(final mode in ['new','resume','replay']) {
      final resumed=mode=='resume';
      var starts=0;
      SharedPreferences.setMockInitialValues(mode!='new'
        ? {'pq.active_attempt.${level.id}':'attempt-test'} : {});
      final session = PuzzleSession(client:ApiClient(client:MockClient((request) async {
        if(request.method=='POST' && request.url.path.endsWith('/attempts')) starts++;
        return http.Response(jsonEncode({'id':'attempt-test',
          'state':mode=='replay' && request.method=='GET'?'completed':'playing',
          'placed_piece_ids':resumed?['piece_000']:[], 'elapsed_ms':0}),200,
          headers:{'content-type':'application/json'});
      })));
      await tester.pumpWidget(MaterialApp(theme:puzzleTheme(false),home:Scaffold(
        body:PuzzleGameplay(level:level,session:session,onCompleted:(_){},onExit:(){}))));
      for(var i=0;i<40 && find.byWidgetPredicate((widget) => widget is GameWidget).evaluate().isEmpty;i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds:50)));
        await tester.pump(const Duration(milliseconds:50));
      }
      expect(tester.takeException(),isNull);
      expect(find.byWidgetPredicate((widget) => widget is GameWidget),findsOneWidget,reason:'resumed: $resumed');
      final game = tester.widget<GameWidget>(find.byWidgetPredicate((widget) => widget is GameWidget)).game as FlameGame;
      for(var i=0;i<60;i++) {
        await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds:20)));
        await tester.pump(const Duration(milliseconds:20));
      }
      expect(game.isLoaded,isTrue,reason:'engine loaded, resumed: $resumed');
      expect(game.children.whereType<SpriteComponent>().length,resumed?1:0);
      expect(starts,mode=='resume'?0:1,reason:'$mode must create or restore the correct attempt');
      await tester.pumpWidget(const SizedBox());
      session.dispose();
    }
  });
}
