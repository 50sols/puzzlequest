import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzlequest_game/core/session.dart';
import 'package:puzzlequest_game/screens/screens.dart';

void main(){
  testWidgets('All forty approved IDs have screen routes', (tester) async {
    final session=PuzzleSession();
    // Do not initialize: this checks statically defined page bindings, not network calls.
    for(final id in [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15,16,17,18,19,20,21,22,23,24,25,26,27,28,29,30,31,32,33,34,35,36,37,38,39,40]){
      expect(ScreenPage(session:session,id:id).id,id);
    }
    expect(find.byType(Scaffold),findsNothing);
    session.dispose();
  });
}
