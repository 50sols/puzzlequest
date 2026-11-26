import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'core/session.dart';
import 'core/theme.dart';
import 'screens/screens.dart';
import 'widgets/pq_widgets.dart';
import 'widgets/app_footer_banner.dart';
import 'core/ads_service.dart';
import 'core/orientation.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Apply portrait orientation before rendering the first frame.
  await lockPuzzleQuestPortrait();
  final session=PuzzleSession();
  runApp(PuzzleQuestApp(session:session));
  await session.initialize();
}

class PuzzleQuestApp extends StatelessWidget {
  const PuzzleQuestApp({super.key,required this.session});
  final PuzzleSession session;
  @override Widget build(BuildContext context)=>AnimatedBuilder(animation:session,builder:(context,_)=>MaterialApp(
    title:'PuzzleQuest',debugShowCheckedModeBanner:false,
    theme:puzzleTheme(session.arabic),
    locale:Locale(session.arabic?'ar':'en'),
    supportedLocales:const [Locale('ar'),Locale('en')],
    localizationsDelegates:const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    builder:(context,child)=>Directionality(textDirection:session.arabic?TextDirection.rtl:TextDirection.ltr,
      child:PQBackdrop(child:Column(children:[
        Expanded(child:child??const SizedBox()),
        if(RewardedAdsService.canPreviewTestAd)
          const SafeArea(top:false,child:AppFooterBanner()),
      ]))),
    home:ScreenPage(
      key: ValueKey(session.ready ? (session.offline ? 37 : session.authenticated ? 2 : 18) : 1),
      session: session,
      id: session.ready ? (session.offline ? 37 : session.authenticated ? 2 : 18) : 1,
      extra: const {'startup': true},
    ),
  ));
}
