import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puzzlequest_game/core/session.dart';
import 'package:puzzlequest_game/widgets/avatar_picker.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('all eight real avatar asset paths render in two-column picker',
      (tester) async {
    String? chosen;
    await tester.pumpWidget(MaterialApp(home:Scaffold(body:
      SingleChildScrollView(child:SizedBox(width:320,child:
        PuzzleAvatarPicker(
          selectedId:'explorer_boy_blue',arabic:false,
          onSelected:(id)=>chosen=id),
      )),
    )));
    expect(puzzleAvatars.length,8);
    for(final avatar in puzzleAvatars){
      expect(find.byWidgetPredicate((widget)=>widget is Image &&
        widget.image is AssetImage &&
        (widget.image as AssetImage).assetName==avatar.asset),findsOneWidget);
    }
    expect(find.byIcon(Icons.check_circle_rounded),findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('avatar-explorer_boy_blue')));
    await tester.pump();
    expect(chosen,'explorer_boy_blue');
  });

  test('offline guest can start and choose avatar without an API', () async {
    SharedPreferences.setMockInitialValues({});
    final session=PuzzleSession();
    try{
      await session.startOfflinePractice();
      expect(session.offline,true);
      expect(session.offlineGuest,true);
      expect(session.authenticated,false);
      expect(session.practiceMode,true);
      expect(session.levels.length,greaterThanOrEqualTo(5));
      expect(session.levels.every((level)=>level.unlocked),true);
      await session.chooseAvatar('explorer_girl_purple');
      expect(session.player['avatar'],'explorer_girl_purple');
      final prefs=await SharedPreferences.getInstance();
      expect(prefs.getString('puzzlequest.pending_avatar'),'explorer_girl_purple');
    }finally{session.dispose();}
  });
}
