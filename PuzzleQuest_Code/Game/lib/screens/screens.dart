import '../widgets/puzzle_dialog.dart';
import 'dart:async';
import 'dart:math' as math;
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart' as picker;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../core/api.dart';
import '../core/ads_service.dart';
import '../core/models.dart';
import '../core/session.dart';
import '../core/theme.dart';
import '../widgets/pq_widgets.dart';
import '../widgets/component_library.dart';
import '../widgets/verified_level_image.dart';
import '../widgets/waterfall_motion.dart';
import '../widgets/reward_shine.dart';
import '../widgets/game_art_button.dart';
import '../game/gameplay.dart';

const _screenTitles=<int, List<String>>{
  1:['شاشة البداية','Splash'],2:['قريتي','My Village'],3:['العوالم','Worlds'],
  4:['المراحل','Levels'],5:['معاينة المرحلة','Level Preview'],6:['اللعب','Gameplay'],
  7:['انتهت المرحلة','Level Complete'],8:['المهام والأحداث','Missions & Events'],
  9:['المجموعة','Collections'],10:['الترتيب الأسبوعي العالمي','Weekly Global'],
  11:['المتجر','Shop'],12:['الملف والإعدادات','Profile & Settings'],
  13:['عرض الصورة','Full Image'],14:['التلميحات','Hints'],15:['إيقاف مؤقت','Pause'],
  16:['صندوق المكافأة','Reward Chest'],17:['معاينة الصورة','Full Image Reward'],
  18:['مرحبًا في PuzzleQuest','Welcome'],19:['تسجيل الدخول','Sign In'],
  20:['إنشاء حساب','Create Account'],21:['رمز التحقق','Email Verification'],
  22:['نسيت كلمة المرور','Forgot Password'],23:['إعادة تعيين كلمة المرور','Reset Password'],
  24:['اللعب كضيف','Play as Guest'],25:['اختر شخصية','Choose Avatar'],
  26:['حسابي','My Account'],27:['تعديل الملف','Edit Profile'],
  28:['الخصوصية والأمان','Privacy & Security'],29:['حفظ تقدم الضيف','Save Guest Progress'],
  30:['حذف الحساب','Delete Account'],31:['طريقة اللعب','Tutorial'],
  32:['تطوير القرية','Village Upgrades'],33:['المكافأة اليومية','Daily Reward'],
  34:['الإنجازات','Achievements'],35:['صندوق الوارد','Inbox'],
  36:['المساعدة والدعم','Help & Support'],37:['الاتصال','Connection Recovery'],
  38:['الإعلان غير متاح','Ad Unavailable'],39:['حالات النظام','System States'],
  40:['خيارات الخصوصية','Privacy Consent'],
};

class ScreenPage extends StatefulWidget {
  const ScreenPage({super.key,required this.session,required this.id,this.extra=const {}});
  final PuzzleSession session;final int id;final Map<String,dynamic> extra;
  @override State<ScreenPage> createState()=>_ScreenPageState();
}
class _ScreenPageState extends State<ScreenPage> {
  bool _completionPending = false;
  int _levelPage = 0;
  int _tutorialStep = 0;
  bool _showEvents = false;
  bool _showBadges = false;
  String? _selectedBuilding;
  final _gameplayKey = GlobalKey<PuzzleGameplayState>();
  PuzzleSession get s=>widget.session;
  int get id=>widget.id;
  Future<void> _navigate(int target,[Map<String,dynamic> extra=const {}]) async {
    if (target == 5 && s.authenticated) {
      try { await s.refreshCatalog(); } catch (_) {}
      if (!mounted) return;
    }
    await Navigator.push(context,MaterialPageRoute(builder:(_)=>ScreenPage(session:s,id:target,extra:extra)));
    if (mounted) setState(() {
      if (id == 2 || id == 3 || id == 4) {
        _queries.remove('collections');
        _queries.remove('village');
        _queries.remove('missions');
      }
    });
  }
  void _home() => Navigator.of(context).pushAndRemoveUntil(
    MaterialPageRoute(builder:(_)=>ScreenPage(session:s,id:2)),(_)=>false);
  bool _handlingAction=false;
  Future<void> _perform(Future<void> Function() body, {int? next}) async {
    if(_handlingAction)return; // UI double taps must not double-spend.
    _handlingAction=true;
    try{await body();if(!mounted){return;}if(next!=null) {if(next==2){_home();}else{_navigate(next);}} else {setState((){});}}
    catch (e) {
      if (mounted) await showPuzzleMessage(context, _errorText(e), warning: true);
    }
    finally{_handlingAction=false;}
  }
  String _errorText(Object e) {
    if(e is ApiException){if(e.status==0)return s.tr('لا يوجد اتصال بالخادم. حاول لاحقًا.','Cannot connect to server. Try again.');
      if(e.status==401)return s.tr('بيانات الدخول غير صحيحة','Invalid credentials');
      if(e.status==503)return s.tr('الخدمة غير مهيأة بعد، راجع إعدادات الخادم','Service not configured on server');
      switch (e.message) {
        case 'building_goal_not_met':
          return s.tr('أكمل المرحلة المطلوبة والمذكورة تحت المبنى، وبعدها جرّب الترميم مرة تانية.',
            'Complete the required level shown below the building, then try restoring it again.');
        case 'building_stage_changed':
          return s.tr('حالة المبنى اتغيّرت. ارجع لشاشة القرية وافتحه تاني.',
            'The building has changed. Open it again from your village.');
        case 'insufficient_coins':
        case 'insufficient_balance':
          return s.tr('رصيد العملات غير كافٍ لإتمام العملية.', 'You don’t have enough coins for this action.');
        default:
          return s.tr('تعذّر إتمام العملية. حاول مرة تانية.', 'Couldn’t complete the action. Please try again.');
      }
    }
    return s.tr('حدث خطأ. حاول مرة تانية.', 'Something went wrong. Please try again.');
  }
  String _title()=>s.arabic?_screenTitles[id]![0]:_screenTitles[id]![1];
  @override Widget build(BuildContext context){
    if (id == 1) return Scaffold(body: SafeArea(child: _splash()));
    if (id == 2) {
      return Scaffold(body: SafeArea(
        child: LayoutBuilder(builder: (context, bounds) {
          return Center(child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Column(children: [
              Expanded(child: _homeScreen()),

            ]),
          ));
        }),
      ));
    }
    final hasBottomNav=id == 11;
    return Scaffold(
      body:PQBackdrop(bright:[2,3,4].contains(id),child:SafeArea(child:Column(children:[
        if (const [3, 4, 5, 8, 9, 10, 11, 33].contains(id))
          _worldsHeader(title: id == 33 ? s.tr('تسجيل الدخول اليومي', 'Daily check-in') : id == 4 ? _levelWorldName : id == 5 && _currentLevel != null
            ? s.tr('المرحلة ${_currentLevel!.code}', 'Level ${_currentLevel!.code}') : null)
        else if (s.authenticated && id != 6) _villageHeader()
        else if (id != 18 && id != 6) Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: Row(children: [
            BackButton(onPressed: () => Navigator.maybePop(context)),
            Expanded(child: PQTopBar(session: s, title: _title())),
          ]),
        ),
        Expanded(child:_body()),
        if(hasBottomNav)_bottomNavigation(),
      ]))),
    );
  }
  Widget _villageHomeButton() => IconButton(
    tooltip: s.tr('العودة إلى قريتي', 'Back to My Village'),
    constraints: const BoxConstraints.tightFor(width: 80, height: 48),
    padding: const EdgeInsets.all(4),
    onPressed: () async {
      final gameplay = _gameplayKey.currentState;
      if (gameplay != null && !await gameplay.prepareToLeave()) return;
      if (mounted) _home();
    },
    icon: Image.asset('assets/branding/logo.png',
      width: 72, height: 40, fit: BoxFit.contain, excludeFromSemantics: true),
  );

  Widget _villageHeader() => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 8),
    child: Row(children: [
      Expanded(child: Row(children: [
        BackButton(onPressed: () => Navigator.maybePop(context)),
        Expanded(child: Text(_title(), maxLines: 2, overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.titleSmall)),
      ])),
      _villageHomeButton(),
      Expanded(child: Align(alignment: AlignmentDirectional.centerEnd,
        child: FittedBox(fit: BoxFit.scaleDown, child: Row(children: [
          PQHUDCurrency(label: s.tr('العملات', 'Coins'), amount: s.coins),
          const SizedBox(width: 4),
          PQHUDCurrency(label: s.tr('النجوم', 'Stars'), amount: s.stars,
            icon: Icons.star_rounded),
        ])),
      )),
    ]),
  );

  Widget _bottomNavigation()=>SafeArea(top:false,child:Container(
    color:PQColors.background.withValues(alpha:.92),height:70,
    child:Row(mainAxisAlignment:MainAxisAlignment.spaceAround,children:[
      _nav(Icons.home_filled,2,s.tr('الرئيسية','Home')),
      _nav(Icons.public,3,s.tr('العوالم','Worlds')),
      _nav(Icons.assignment_turned_in,8,s.tr('المهام','Missions')),
      _nav(Icons.collections,9,s.tr('المجموعة','Collection')),
      _nav(Icons.storefront,11,s.tr('المتجر','Shop')),
    ]),
  ));
  Widget _nav(IconData icon,int target,String label)=>InkWell(
    onTap:()=>target==id?null:_navigate(target),child:Column(mainAxisAlignment:MainAxisAlignment.center,children:[
      Icon(icon,color:target==id?PQColors.gold:PQColors.white,size:24),
      Text(label,style:TextStyle(fontSize:10,color:target==id?PQColors.gold:PQColors.white)),
    ]));
  Widget _body(){switch(id){
    case 1:return _splash(); case 2:return _homeScreen();case 3:return _worlds();
    case 4:return _levels();case 5:return _levelPreview();case 6:return _play();case 7:return _complete();
    case 8:return _missions();case 9:return _collections();case 10:return _leaderboard();
    case 11:return _shop();case 12:return _profileSettings();case 13:return _gameOverlayInfo('full');
    case 14:return _gameOverlayInfo('hint');case 15:return _gameOverlayInfo('pause');
    case 16:return _chest();case 17:return _gameOverlayInfo('preview');
    case 18:return _welcome();case 19:return _signIn();case 20:return _register();
    case 21:return _otp();case 22:return _forgot();case 23:return _reset();case 24:return _guest();
    case 25:return _avatars();case 26:return _account();case 27:return _editProfile();
    case 28:return _privacy();case 29:return _guestMerge();case 30:return _deleteAccount();
    case 31:return _tutorial();case 32:return _village();case 33:return _daily();
    case 34:return _achievements();case 35:return _inbox();case 36:return _support();
    case 37:return _connection();case 38:return _adUnavailable();case 39:return _systemStates();
    case 40:return _consent();default:return PQEmpty(text:_title());
  }}
  Widget _scroll(Widget child)=>SingleChildScrollView(padding:const EdgeInsets.fromLTRB(16,8,16,24),child:child);
  Widget _stack(List<Widget> children)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:children);
  Widget _splash() => LayoutBuilder(builder: (context, bounds) {
    final scale = math.min(1.0, math.min(bounds.maxWidth / 390, bounds.maxHeight / 844));
    return Center(child: SizedBox(width: 390 * scale, height: 844 * scale,
      child: Stack(children: [
        Positioned(left: 48 * scale, top: 160 * scale,
          width: 294 * scale, height: 360 * scale,
          child: DecoratedBox(decoration: _splashPanel())),
        Positioned(left: 48 * scale, top: 185 * scale,
          width: 294 * scale, height: 300 * scale,
          child: Image.asset('assets/branding/logo.png', fit: BoxFit.contain)),
        Positioned(left: 32 * scale, top: 728 * scale,
          width: 326 * scale, height: 56 * scale,
          child: Container(decoration: _splashPanel(),
            padding: EdgeInsets.symmetric(horizontal: 8 * scale),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Text(s.tr('جارٍ التحميل…', 'Loading…'),
              style: TextStyle(fontSize: 12 * scale)),
            const SizedBox(height: 8),
            if (!s.reduceMotion && !MediaQuery.disableAnimationsOf(context))
              const LinearProgressIndicator(color: PQColors.gold),
          ]))),
      ]),
    ));
  });
  BoxDecoration _splashPanel() => BoxDecoration(
    color: const Color(0xFF211D47),
    border: Border.all(color: const Color(0xFF655A8A)),
    borderRadius: BorderRadius.circular(10),
  );
  Widget _authLayout(List<Widget> children, {bool welcome = false}) => LayoutBuilder(
    builder: (context, bounds) => Stack(fit: StackFit.expand, children: [
      SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Center(child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: 326,
            minHeight: welcome ? math.max(0.0, bounds.maxHeight - 32) : 0),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: welcome ? MainAxisAlignment.spaceBetween : MainAxisAlignment.start,
            children: children),
        )),
      ),
    ]),
  );

  Widget _authArt(String icon) => Center(child: Image.asset(
    'assets/design/ui/icons/$icon.png', width: 96, height: 96,
    fit: BoxFit.contain, excludeFromSemantics: true,
  ));

  Widget _welcome() => _authLayout([
    Padding(padding: const EdgeInsets.only(top: 48),
      child: Image.asset('assets/branding/logo.png', width: 198, height: 160, fit: BoxFit.contain)),
    Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      PQAction(label: s.tr('إنشاء حساب', 'Create Account'), onPressed: () => _navigate(20)),
      const SizedBox(height: 12),
      PQAction(label: s.tr('تسجيل الدخول', 'Sign In'), outlined: true, onPressed: () => _navigate(19)),
      const SizedBox(height: 8),
      TextButton(onPressed: () => _navigate(24), child: Text(s.tr('العب كضيف', 'Play as Guest'))),
      TextButton(onPressed: () => _navigate(40), child: Text(s.tr('خيارات الخصوصية', 'Privacy options'))),
      TextButton(onPressed: () => s.setLanguage(!s.arabic), child: Text(s.arabic ? 'English' : 'العربية')),
    ]),
  ], welcome: true);
  Widget _homeScreen()=>LayoutBuilder(builder:(context,constraints){
    final viewportHeight = constraints.maxHeight;
    final scale = (viewportHeight / 844).clamp(.68, 1.0).toDouble();
    final gap = 6 * scale;
    return Column(children: [
      Expanded(child: LayoutBuilder(builder: (context, body) {
        final fixedHeight = 188 * scale + (s.offline ? 30 : 0);
        final sceneHeight = math.max(120.0, body.maxHeight - fixedHeight);
        return SingleChildScrollView(padding: EdgeInsets.fromLTRB(16, 8 * scale, 16, 0),
      child:Column(children:[
        _homeHeader(scale), SizedBox(height: gap),
        _villageProgress(scale), SizedBox(height: gap),
        SizedBox(height: sceneHeight, child: OverflowBox(
          minWidth: constraints.maxWidth, maxWidth: constraints.maxWidth,
          child: _villageScene(sceneHeight))),
        SizedBox(height:gap),
        if(s.offline)Padding(padding:const EdgeInsets.only(top:8),
          child:Text(s.tr('تعمل في وضع محدود دون اتصال','Limited offline mode'),
            style:const TextStyle(color:PQColors.muted,fontSize:12))),
      ]),
        );
      })),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Directionality(textDirection: TextDirection.ltr, child: LayoutBuilder(
          builder: (context, row) => SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SizedBox(width: math.max(row.maxWidth, 354.0), child: Row(children: [
          Expanded(child: _homeShortcut('assets/design/art/worlds/floating_island.png', s.tr('العوالم', 'Worlds'), 0, () => _navigate(3))),
          const SizedBox(width: 3),
          Expanded(child: FutureBuilder<Map<String, dynamic>>(
            future: s.authenticated
                ? _queries.putIfAbsent('missions', () => s.api.get('missions'))
                : null,
            builder: (context, snapshot) {
              final pending = arr(snapshot.data?['missions']).map(obj)
                  .where((mission) => mission['eligible'] == true && mission['claimed'] != true).length;
              return _homeShortcut('assets/design/art/rewards/puzzle_piece.png', s.tr('المهام', 'Missions'), pending,
                () => _navigate(8));
            },
          )),
          const SizedBox(width:3),
          Expanded(child:_homeShortcut('assets/design/art/worlds/hot_air_balloon.png',s.tr('الأحداث','Events'),0,
            ()=>_navigate(8, {'events': true}))),
          const SizedBox(width:3),
          Expanded(child:_homeShortcut('assets/design/art/rewards/coins_stack.png',s.tr('المتجر','Shop'),0,()=>_navigate(11))),
          const SizedBox(width: 3),
          Expanded(child: _homeShortcut('assets/design/art/worlds/green_valley_puzzle_thumb.png', s.tr('المجموعة', 'Collection'), 0, () => _navigate(9))),
          const SizedBox(width: 3),
          Expanded(child: _homeShortcut('assets/ui/buttons/rank_art.png', s.tr('الترتيب', 'Rank'), 0, () => _navigate(10))),
        ])),
          ),
        ))),
      if (RewardedAdsService.canPreviewTestAd)
        TextButton.icon(
          onPressed: () => _perform(RewardedAdsService.previewTestAd),
          icon: const Icon(Icons.ondemand_video),
          label: Text(s.tr('اعرض إعلان تجريبي', 'Show test ad')),
        ),
      Padding(padding: const EdgeInsets.symmetric(horizontal: 32),
        child: _HomePlayShine(
          enabled: !s.reduceMotion && !MediaQuery.disableAnimationsOf(context),
          child: GameArtButton(asset:'assets/ui/buttons/play_art.png',
            label:s.tr('العب','Play'),crop:const Rect.fromLTRB(.03,.12,.97,.88),
            sourceAspectRatio:3,onPressed:()=>_navigate(3)))),
    ]);
  });
  Widget _homeHeader(double scale){
    final avatar='${s.player['avatar']??''}';
    final avatarPath=avatar.isNotEmpty&&RegExp(r'^[a-z0-9_]+$').hasMatch(avatar)
      ?'assets/design/art/characters/avatars/$avatar.png'
      :'assets/design/art/characters/hero_avatar.png';
    return SizedBox(height:64*scale,child:Directionality(textDirection:TextDirection.ltr,child:Row(children:[
      Semantics(button:true,label:s.tr('حسابي','My account'),child:InkWell(
        onTap:()=>_navigate(26),borderRadius:BorderRadius.circular(32),
        child:ClipOval(child:Image.asset(avatarPath,width:math.max(48.0,64*scale),height:math.max(48.0,64*scale),fit:BoxFit.cover,
          errorBuilder:(context,error,stack)=>Image.asset(
            'assets/design/art/characters/hero_avatar.png',width:math.max(48.0,64*scale),height:math.max(48.0,64*scale),fit:BoxFit.cover))),
      )),
      SizedBox(width:10*scale),Expanded(child:Text(s.displayName,maxLines:2,
        overflow:TextOverflow.ellipsis,style:Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight:FontWeight.w700))),
      SizedBox(width:10*scale),Container(width:158,height:64*scale,padding:EdgeInsets.symmetric(horizontal:10*scale,vertical:5*scale),
        decoration: BoxDecoration(color: PQColors.background.withValues(alpha: .52),
          borderRadius: BorderRadius.circular(20)),
        child:Column(mainAxisAlignment:MainAxisAlignment.spaceEvenly,children:[
          _homeBalance('coin',s.tr('العملات','Coins'),s.authenticated?s.coins:null,scale),
          Divider(height:1,color:PQColors.muted.withValues(alpha:.2)),
          _homeBalance('hint',s.tr('التلميحات','Hints'),s.authenticated?s.hints:null,scale),
        ])),
    ])));
  }
  Widget _homeBalance(String icon,String label,int? amount,double scale)=>Row(children:[
    Image.asset('assets/design/art/rewards/${icon=='coin'?'coins_stack':'hint_bulb'}.png',
      width:24*scale,height:24*scale,fit:BoxFit.contain,excludeFromSemantics:true),
    SizedBox(width:7*scale),Expanded(child:Text(label,maxLines:1,overflow:TextOverflow.ellipsis,
      style:TextStyle(fontSize:11*scale,color:PQColors.muted))),
    RewardShine(gold:true,enabled:!s.reduceMotion && !MediaQuery.disableAnimationsOf(context),
      child:Text(amount?.toString()??'—',style:TextStyle(fontSize:14*scale,
        fontWeight:FontWeight.w700,color:PQColors.gold,
        shadows:const [Shadow(color:Color(0x66FFBB31),blurRadius:6)]))),
  ]);
  Widget _villageScene(double height)=>FutureBuilder<Map<String,dynamic>>(
    future:s.authenticated?_queries.putIfAbsent('village',()=>s.api.get('village')):null,
    builder:(context,snapshot){
      final buildings=arr(obj(snapshot.data)['buildings']);
      final cottage=_buildingStage(buildings,'cottage'),windmill=_buildingStage(buildings,'windmill');
      return LayoutBuilder(builder:(context,c)=>Container(height:height,width:double.infinity,
        clipBehavior:Clip.antiAlias,
        decoration: const BoxDecoration(color: PQColors.background),
        child:LayoutBuilder(builder:(context,scene){
          const sourceWidth = 941.0;
          const sourceHeight = 1672.0;
          const cropFraction = .55;
          final cropHeight = sourceHeight * cropFraction;
          final factor = math.max(scene.maxWidth / sourceWidth, scene.maxHeight / cropHeight);
          final w = sourceWidth * factor;
          final h = cropHeight * factor;
          final left = (scene.maxWidth - w) / 2;
          final top = (scene.maxHeight - h) * .34;
          return Stack(children:[
            Positioned(left: left, top: top, width: w, height: h,
              child: ClipRect(child: Stack(children: [
                Positioned(left: 0, bottom: 0, width: w, height: sourceHeight * factor,
                  child: Image.asset('assets/design/art/backgrounds/village_clean.png', fit: BoxFit.fill,
                    cacheWidth: (w * MediaQuery.devicePixelRatioOf(context)).ceil())),
                Positioned(left: 0, bottom: 0, width: w, height: sourceHeight * factor,
                  child: WaterfallMotion(enabled: !s.reduceMotion &&
                    !MediaQuery.disableAnimationsOf(context))),
              ]))),
            if (buildings.isNotEmpty) _buildingSprite(id:'cottage',stage:cottage,x:left+.72*w,y:top+.55*h,
              size:.46*w,onTap:()=>_navigate(32,{'building':'cottage'})),
            if (buildings.isNotEmpty) _buildingSprite(id:'windmill',stage:windmill,x:left+.20*w,y:top+.43*h,
              size:.33*w,onTap:()=>_navigate(32,{'building':'windmill'})),
            const Positioned.fill(child: IgnorePointer(child: DecoratedBox(
              decoration: BoxDecoration(gradient: LinearGradient(
                begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [PQColors.background, Colors.transparent,
                  Colors.transparent, PQColors.background],
                stops: [0, .08, .85, 1],
              )),
            ))),
          ]);
        }),
      ));
    },
  );
  int _buildingStage(List<dynamic> buildings,String id){
    for(final raw in buildings){final building=obj(raw);if(building['id']==id)return number(building['stage']).clamp(0,4).toInt();}
    return 0;
  }
  Widget _buildingSprite({required String id,required int stage,required double x,
    required double y,required double size,required VoidCallback onTap})=>Positioned(
      left:x-size/2,top:y-size*.9,width:size,height:size,
      child:Semantics(button:true,label:s.tr(id=='cottage'?'المنزل':'المطحنة',id=='cottage'?'Cottage':'Windmill'),
        child:GestureDetector(behavior:HitTestBehavior.opaque,onTap:onTap,child:Image.asset(
          'assets/design/art/buildings/stages/${id}_stage_$stage.png',fit:BoxFit.contain,
          errorBuilder:(context,error,stack)=>Image.asset(
            'assets/design/art/buildings/stages/${id}_stage_0.png',fit:BoxFit.contain)))));
  Set<Object?> _completedLevelsFor(Map<String, dynamic>? data) =>
      arr(obj(data)['pictures']).map((entry) => obj(entry)['level_id']).toSet();

  Widget _villageProgress(double scale){
    final future = s.authenticated
        ? _queries.putIfAbsent('collections', () => s.api.get('collections'))
        : null;
    return FutureBuilder<Map<String,dynamic>>(future:future,builder:(context,snapshot){
      final villageLevels = s.levels
          .where((level) => level.worldId == 'green_valley' && level.published)
          .toList();
      final confirmed = _completedLevelsFor(snapshot.data);
      final missing = villageLevels.where((level) => !confirmed.contains(level.id)).toList();
      final total = villageLevels.length;
      final completed = total - missing.length;
      final hasProgress = snapshot.hasData && total > 0;
      final percent = hasProgress ? (100 * completed / total).round() : 0;
      final status = hasProgress
          ? '$completed / $total · $percent%'
          : s.tr('بانتظار المزامنة', 'Awaiting sync');
      return Container(
        constraints: BoxConstraints(minHeight: 116 * scale),
        padding: EdgeInsets.symmetric(horizontal: 16 * scale, vertical: 10 * scale),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
            colors: [Color(0xFF7044CF), Color(0xFF30196E), Color(0xFF4C267C)],
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: const Color(0xFFAE86F1), width: 1.5),
          boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))],
        ),
        child: Row(textDirection: TextDirection.ltr, children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(s.tr('رمّم قريتك', 'Rebuild Your Village'),
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: 23 * scale, fontWeight: FontWeight.w700)),
            Text(hasProgress && missing.isNotEmpty
                ? s.tr('المراحل المتبقية: ${missing.map((level) => level.code).join('، ')}',
                    'Remaining: ${missing.map((level) => level.code).join(', ')}')
                : s.tr('مراحل مكتملة لفتح ترقيات القرية', 'Puzzles completed toward village upgrades'),
              textAlign: TextAlign.left,
              style: TextStyle(fontSize: 14 * scale, color: PQColors.white)),
            SizedBox(height: 7 * scale),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(height: 16 * scale,
                child: LayoutBuilder(builder: (context, bar) => Stack(children: [
                  Positioned.fill(child: Image.asset(
                    'assets/design/ui/progress/bar_track.png', fit: BoxFit.fill)),
                  if (hasProgress && completed > 0)
                    Positioned(left: 0, top: 0, bottom: 0,
                      width: bar.maxWidth * completed / total,
                      child: Image.asset('assets/design/ui/progress/bar_fill.png', fit: BoxFit.fill)),
                ]))),
              SizedBox(height: 4 * scale),
              Text(status, textDirection: hasProgress ? TextDirection.ltr : Directionality.of(context),
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14 * scale)),
            ]),
          ])),
          SizedBox(width: 8 * scale),
          RewardShine(enabled:!s.reduceMotion && !MediaQuery.disableAnimationsOf(context),
            child:Image.asset('assets/design/art/rewards/treasure_chest.png',
              width:88*scale,height:88*scale,fit:BoxFit.contain,excludeFromSemantics:true)),
        ]),
      );
    });
  }
  Widget _homeShortcut(String art, String label, int badge, VoidCallback? onTap) {
    return Semantics(
      button: onTap != null,
      selected: onTap == null,
      label: badge > 0 ? '$label, $badge' : label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(height: 72, child: Stack(alignment: Alignment.topCenter, children: [
          ExcludeSemantics(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Image.asset(art, width: 42, height: 39, fit: BoxFit.contain),
            const SizedBox(height: 3),
            Padding(padding: const EdgeInsets.symmetric(horizontal: 1),
              child: FittedBox(fit: BoxFit.scaleDown, child: Text(label, textAlign: TextAlign.center,
                maxLines: 1, softWrap: false,
                style: TextStyle(fontSize: 11, height: 1.08, fontWeight: FontWeight.w700,
                  color: onTap == null ? PQColors.gold : PQColors.white)))),
          ])),
          if (badge > 0) Positioned(top: 0, right: 0, child: ExcludeSemantics(
            child: Container(
              constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
              padding: const EdgeInsets.symmetric(horizontal: 4),
              alignment: Alignment.center,
              decoration: BoxDecoration(color: const Color(0xFFD9233B),
                borderRadius: BorderRadius.circular(10)),
              child: Text('$badge', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold)),
            ),
          )),
        ])),
      ),
    );
  }

  Widget _worldsHeader({String? title}) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
    child: SizedBox(height: 48, child: Stack(children: [
      PositionedDirectional(start: 0, top: 0, bottom: 0,
        child: BackButton(onPressed: () => Navigator.maybePop(context))),
      Positioned.fill(left: 82, right: 82,
        child: Center(child: FittedBox(fit: BoxFit.scaleDown,
          child: Text(title ?? _title(), maxLines: 1, textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.headlineSmall
              ?.copyWith(fontWeight: FontWeight.w700))))),
      if (s.authenticated) PositionedDirectional(end: 0, top: 0, bottom: 0,
        child: _villageHomeButton()),
    ])),
  );

  Widget _worlds() {
    final catalog = {for (final world in s.worlds) obj(world)['id']: obj(world)};
    final cards = [
      ('green_valley', 'green_valley', s.tr('الوادي الأخضر', 'Green Valley'), PQColors.purple),
      ('snow_land', 'snow_land', s.tr('أرض الثلج', 'Snow Land'), const Color(0xFF8FBFFF)),
      ('desert_ruins', 'desert_city', s.tr('أطلال الصحراء', 'Desert Ruins'), const Color(0xFFF7AA70)),
    ];
    return SingleChildScrollView(
      key: const PageStorageKey('worlds-map'),
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      child: Column(children: [
        for (final (worldId, art, fallback, accent) in cards)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _worldCard(worldId, art, fallback, accent, catalog[worldId]),
          ),
      ]),
    );
  }

  Widget _worldCard(String worldId, String art, String fallback, Color accent,
      Map<String, dynamic>? world) {
    final levels = s.levels.where((level) => level.worldId == worldId && level.published).toList();
    final published = world == null ? worldId == 'green_valley' : world['published'] == true;
    final available = published && levels.any((level) => level.unlocked);
    final title = world == null ? fallback : localized(world['title'], s.arabic);
    final requirement = published
        ? s.tr('أكمل جميع مراحل العالم السابق', 'Complete all levels in the previous world')
        : s.tr('يفتح بعد نشر المحتوى وإكمال العالم السابق',
            'Unlocks when published and after completing the previous world');
    return Container(
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), boxShadow: [
        BoxShadow(color: accent.withValues(alpha: available ? .7 : .23), blurRadius: 12),
      ]),
      child: Material(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: accent, width: 2)),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: available ? () => _navigate(4, {'world': worldId}) : null,
          child: Stack(children: [
            Positioned.fill(child: Image.asset('assets/design/art/worlds/$art.png',
              fit: BoxFit.cover, excludeFromSemantics: true)),
            const Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xE610102A)]),
            ))),
            ConstrainedBox(constraints: BoxConstraints(minHeight: available ? 172 : 146),
              child: Align(alignment: Alignment.bottomCenter,
                child: Padding(padding: const EdgeInsets.all(16),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min, children: [
                        Text(title, style: const TextStyle(fontSize: 23, fontWeight: FontWeight.bold)),
                        if (available)
                          _worldStars(levels)
                        else Text(requirement),
                      ])),
                    if (!available) Padding(
                      padding: const EdgeInsetsDirectional.only(start: 10),
                      child: CircleAvatar(radius: 23, backgroundColor: const Color(0xC0131030),
                        child: Image.asset('assets/design/ui/icons/lock.png',
                          width: 25, height: 25, excludeFromSemantics: true)),
                    ),
                  ]),
                ),
              ),
            ),
          ]),
        ),
      ),
    );
  }
  Widget _worldStars(List<LevelSpec> levels) {
    final levelIds = levels.map((level) => level.id).toSet();
    return FutureBuilder<Map<String, dynamic>>(
      future: s.authenticated
          ? _queries.putIfAbsent('collections', () => s.api.get('collections'))
          : null,
      builder: (context, snapshot) {
        final stars = arr(obj(snapshot.data)['pictures']).map(obj)
            .where((entry) => levelIds.contains(entry['level_id']))
            .fold<int>(0, (sum, entry) => sum + number(entry['best_stars']));
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Image.asset('assets/design/ui/icons/star_gold.png', width: 22, height: 22,
            excludeFromSemantics: true),
          const SizedBox(width: 6),
          Text(snapshot.hasData ? '$stars / ${levels.length * 3}' : '—',
            textDirection: TextDirection.ltr,
            style: const TextStyle(fontWeight: FontWeight.w700)),
        ]);
      },
    );
  }
  String get _levelWorldId => '${widget.extra['world'] ?? 'green_valley'}';

  String get _levelWorldName {
    for (final entry in s.worlds) {
      final world = obj(entry);
      if (world['id'] == _levelWorldId) return localized(world['title'], s.arabic);
    }
    return switch (_levelWorldId) {
      'snow_land' => s.tr('أرض الثلج', 'Snow Land'),
      'desert_ruins' => s.tr('أطلال الصحراء', 'Desert Ruins'),
      _ => s.tr('الوادي الأخضر', 'Green Valley'),
    };
  }

  Widget _levels() {
    final levels = s.levels.where((level) => level.worldId == _levelWorldId && level.published).toList();
    if (levels.isEmpty) return PQEmpty(text: s.tr('لا يوجد محتوى منشور', 'No published content'));
    const perPage = 16;
    final pages = (levels.length / perPage).ceil();
    final page = math.min(_levelPage, pages - 1);
    final art = switch (_levelWorldId) {
      'snow_land' => 'snow_land',
      'desert_ruins' => 'desert_city',
      _ => 'green_valley',
    };
    return FutureBuilder<Map<String, dynamic>>(
      future: s.authenticated ? _queries.putIfAbsent('collections', () => s.api.get('collections')) : null,
      builder: (context, snapshot) {
        final ratings = {
          for (final item in arr(obj(snapshot.data)['pictures']).map(obj))
            item['level_id']: number(item['best_stars']).clamp(0, 3).toInt(),
        };
        final earned = levels.fold<int>(0, (sum, level) => sum + (ratings[level.id] ?? 0));
        final maximum = levels.length * 3;
        return _scroll(_stack([
          ClipRRect(
            borderRadius: BorderRadius.circular(18),
            child: Stack(children: [
              Positioned.fill(child: Image.asset('assets/design/art/worlds/$art.png',
                fit: BoxFit.cover, excludeFromSemantics: true)),
              Positioned.fill(child: DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, PQColors.background.withValues(alpha: .95)]),
              ))),
              Padding(padding: const EdgeInsets.fromLTRB(16, 60, 12, 12),
                child: Row(textDirection: TextDirection.ltr, children: [
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Row(textDirection: TextDirection.ltr, children: [
                      _levelRatingStar(25, earned: true),
                      const SizedBox(width: 8),
                      Text(snapshot.hasData ? '$earned / $maximum' : '— / $maximum',
                        textDirection: TextDirection.ltr,
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                    ]),
                    const SizedBox(height: 8),
                    ClipRRect(borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(value: earned / maximum, minHeight: 12,
                        color: PQColors.gold, backgroundColor: PQColors.background,
                        semanticsLabel: s.tr('تقدم العالم', 'World progress'))),
                  ])),
                  const SizedBox(width: 12),
                  Image.asset('assets/design/art/rewards/treasure_chest.png', width: 62,
                    height: 58, fit: BoxFit.contain, excludeFromSemantics: true),
                ])),
            ]),
          ),
          const SizedBox(height: 20),
          LayoutBuilder(builder: (context, bounds) {
            const gap = 12.0;
            final columns = ((bounds.maxWidth + gap) / (48 + gap)).floor().clamp(1, 4).toInt();
            final size = (bounds.maxWidth - gap * (columns - 1)) / columns;
            return Wrap(textDirection: TextDirection.ltr, spacing: gap, runSpacing: gap, children: [
              for (final (index, level) in levels.skip(page * perPage).take(perPage).indexed)
                SizedBox(width: size, height: math.min(size, 104.0),
                  child: _levelGridTile(level, page * perPage + index + 1, ratings[level.id] ?? 0)),
            ]);
          }),
          if (pages > 1) Padding(padding: const EdgeInsets.only(top: 20), child: Wrap(
            alignment: WrapAlignment.center, children: [
              for (var index = 0; index < pages; index++)
                IconButton(tooltip: s.tr('صفحة ${index + 1}', 'Page ${index + 1}'),
                  onPressed: () => setState(() => _levelPage = index),
                  icon: Icon(Icons.circle, size: 12, color: page == index ? PQColors.white : PQColors.purple)),
            ],
          )),
        ]));
      },
    );
  }

  Widget _levelGridIcon(String name, double size) => Image.asset(
    'assets/design/ui/icons/$name.png', width: size, height: size, excludeFromSemantics: true);

  Widget _levelRatingStar(double size, {required bool earned}) => ShaderMask(
    shaderCallback: (bounds) => const LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(0xFFFFF1A2), Color(0xFFFFBC20), Color(0xFFF2910A)],
    ).createShader(bounds),
    child: Icon(earned ? Icons.star_rounded : Icons.star_border_rounded,
      size: size, color: earned ? Colors.white : Colors.white38),
  );

  Widget _levelGridTile(LevelSpec level, int position, int stars) {
    final playable = level.unlocked || stars > 0;
    final completed = stars > 0;
    final colors = completed
        ? const [Color(0xFF55C126), Color(0xFF145417)]
        : playable ? const [Color(0xFFCF59F6), Color(0xFF5622C8)]
        : const [Color(0xFF504886), Color(0xFF282349)];
    return Semantics(
      label: s.tr('المرحلة ${level.code}', 'Level ${level.code}'),
      enabled: playable,
      button: playable,
      child: Container(
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(16), boxShadow: [
          BoxShadow(color: playable && !completed ? const Color(0xAAAD54FD) : Colors.black54,
            blurRadius: 8, offset: const Offset(0, 3)),
        ]),
        child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: Ink(
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(16),
              border: Border.all(color: colors.first.withValues(alpha: .95), width: 2),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors)),
            child: InkWell(onTap: playable ? () => _navigate(5, {'level': level.id}) : null,
              child: Padding(padding: const EdgeInsets.all(4), child: FittedBox(fit: BoxFit.scaleDown,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  Text('$position', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w700)),
                  if (completed)
                    Row(mainAxisSize: MainAxisSize.min, textDirection: TextDirection.ltr, children: [
                      for (var i = 0; i < 3; i++)
                        _levelRatingStar(17, earned: i < stars),
                    ])
                  else if (playable)
                    const Icon(Icons.play_arrow_rounded, size: 24)
                  else
                    _levelGridIcon('lock', 20),
                ]),
              ))),
          ),
        ),
      ),
    );
  }
  LevelSpec? get _currentLevel=>s.level('${widget.extra['level']??''}');
  Widget _levelPreview() {
    final level = _currentLevel;
    if (level == null) return PQEmpty(text: s.tr('المرحلة غير متاحة', 'Level unavailable'));
    final minutes = (level.limit ~/ 60).toString().padLeft(2, '0');
    final seconds = (level.limit % 60).toString().padLeft(2, '0');
    final heading = Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold);
    return LayoutBuilder(builder: (context, bounds) {
      final density = (bounds.maxHeight / 720).clamp(.65, 1.0).toDouble();
      final gap = 16 * density;
      return Center(child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 390),
      child: Column(children: [
        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 294),
              child: Container(
                width: double.infinity, height: 220 * density,
                foregroundDecoration: BoxDecoration(
                  border: Border.all(color: PQColors.white, width: 2.5),
                  borderRadius: BorderRadius.circular(20)),
                decoration: BoxDecoration(color: PQColors.surface, borderRadius: BorderRadius.circular(20)),
                clipBehavior: Clip.antiAlias,
                child: VerifiedLevelImage(level: level, fit: BoxFit.cover),
              ),
            )),
            SizedBox(height: gap),
            Row(children: [
              Expanded(child: _previewMetric(_previewArt('puzzle_piece', 32 * density),
                s.tr('${level.pieceCount} قطعة', '${level.pieceCount} pieces'))),
              const SizedBox(width: 16),
              Expanded(child: _previewMetric(const Icon(Icons.timer_outlined, size: 30),
                s.tr('الحد $minutes:$seconds', 'Limit $minutes:$seconds'))),
            ]),
            SizedBox(height: gap),
            _previewPanel(minHeight: 112 * density, child: Row(children: [
              _levelGridIcon('missions_gold', 42 * density),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min, children: [
                  Text(s.tr('الهدف', 'Goal'), style: heading),
                  Text(s.tr('ركّب كل القطع لإكمال الصورة قبل انتهاء الوقت.',
                    'Fit all the pieces to complete the picture before time runs out.')),
                ])),
            ])),
            SizedBox(height: gap),
            _previewPanel(minHeight: 116 * density, child: Column(
              crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.tr('المكافآت', 'Rewards'), style: heading),
                const SizedBox(height: 8),
                Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  _previewReward(_previewArt('coins_stack', 33 * density), s.tr('٥٠٠ لأول إكمال', '500 on first clear')),
                  _previewReward(_levelRatingStar(33 * density, earned: true), s.tr('حتى ٣ نجوم', 'Up to 3 stars')),
                  _previewReward(_previewArt('puzzle_piece', 33 * density), s.tr('صورة للمجموعة', 'Collection picture')),
                ]),
              ],
            )),
          ]),
        )),
        Padding(padding: const EdgeInsets.fromLTRB(32, 8, 32, 12),
          child: Row(children: [
            Expanded(child: PQAction(label: s.tr('ابدأ المرحلة', 'Start Level'), icon: Icons.play_arrow,
              onPressed: level.unlocked ? () => _navigate(6, {'level': level.id}) : null)),
            PopupMenuButton<String>(
              tooltip: s.tr('خيارات المرحلة', 'Level options'),
              onSelected: (action) {
                if (action == 'offline') {
                  _navigate(6, {'level': level.id, 'offline': true});
                } else {
                  _navigate(31);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 'offline', enabled: level.unlocked,
                  child: Text(s.tr('اللعب دون اتصال (تذكرة خادم)', 'Play Offline (server ticket)'))),
                PopupMenuItem(value: 'help', child: Text(s.tr('طريقة اللعب', 'How to Play'))),
              ],
            ),
          ]),
        ),
      ]),
      ));
    });
  }

  Widget _previewArt(String name, double size) => Image.asset(
    'assets/design/art/rewards/$name.png', width: size, height: size,
    fit: BoxFit.contain, excludeFromSemantics: true);

  Widget _previewPanel({required double minHeight, required Widget child}) => Container(
    constraints: BoxConstraints(minHeight: minHeight),
    alignment: AlignmentDirectional.centerStart,
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [Color(0xFF382764), Color(0xFF211D47)]),
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: const Color(0xFF655A8A)),
      boxShadow: const [BoxShadow(color: Colors.black38, blurRadius: 5, offset: Offset(0, 3))],
    ),
    child: child,
  );

  Widget _previewMetric(Widget icon, String label) => ConstrainedBox(
    constraints: const BoxConstraints(minHeight: 48),
    child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      icon,
      const SizedBox(width: 6),
      Flexible(child: Text(label, style: const TextStyle(fontWeight: FontWeight.bold))),
    ]),
  );

  Widget _previewReward(Widget icon, String label) => Expanded(child: Column(
    children: [icon, const SizedBox(height: 4), Text(label, textAlign: TextAlign.center)],
  ));

  Widget _play(){final level=_currentLevel;
    if(level==null)return PQEmpty(text:s.tr('المرحلة غير متاحة','Level unavailable'));
    final gameplay = PuzzleGameplay(key:_gameplayKey,level:level,session:s,offlineTicket:widget.extra['offline']==true,
      onExit:()=>Navigator.pop(context),
      onLocalCompleted: () {
        if (mounted) setState(() => _completionPending = true);
      },
      onCompleted: (response) {
        if (!mounted) return;
        unawaited(s.refreshPlayer().catchError((Object _) {}));
        Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) =>
          ScreenPage(session: s, id: 7, extra: {'level': level.id, 'result': response})));
      },
    );
    return Stack(fit: StackFit.expand, children: [
      Offstage(offstage: _completionPending, child: gameplay),
      if (_completionPending) _completionView(level, const {}, pending: true),
    ]);
  }

  Widget _complete() => _completionView(_currentLevel, obj(widget.extra['result']));

  Widget _completionView(LevelSpec? level, Map<String, dynamic> result, {bool pending = false}) {
    final rating = number(result['rating']).clamp(0, 3);
    return Stack(fit: StackFit.expand, children: [
      Image.asset('assets/images/celebrate.png', fit: BoxFit.cover, excludeFromSemantics: true),
      Column(children: [
        Expanded(child: SingleChildScrollView(padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 358),
          child: Column(children: [
            if (rating == 3)
              Image.asset('assets/design/art/rewards/stars_three.png',
                width: 210, height: 82, fit: BoxFit.contain)
            else
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                for (var i = 0; i < 3; i++)
                  SizedBox(width: i == 1 ? 68 : 55, height: 82,
                    child: ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        begin: Alignment.topCenter, end: Alignment.bottomCenter,
                        colors: [Color(0xFFFFF1A2), Color(0xFFFFBC20), Color(0xFFF2910A)],
                      ).createShader(bounds),
                      child: Icon(i < rating ? Icons.star_rounded : Icons.star_border_rounded,
                        size: i == 1 ? 68 : 55, color: i < rating ? Colors.white : Colors.white38),
                    )),
              ]),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [Color(0xFFFF587C), Color(0xFFD4165C)]),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: const Color(0xFFFFACC5), width: 2),
                boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 8, offset: Offset(0, 4))],
              ),
              child: Text(s.tr('اكتملت المرحلة!', 'Level Complete!'), textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w700)),
            ),
            const SizedBox(height: 12),
            if (level != null) Container(
              width: 262, height: 262, clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(18),
                border: Border.all(color: PQColors.white, width: 3), boxShadow: const [
                  BoxShadow(color: Color(0xFFFF759A), blurRadius: 14),
                ]),
              child: VerifiedLevelImage(level: level, width: 262, height: 262),
            ),
            const SizedBox(height: 18),
            if (pending) ...[
              Text(s.tr('اكتملت الصورة — المكافأة قيد المزامنة', 'Puzzle complete — reward awaiting sync'),
                textAlign: TextAlign.center),
              const SizedBox(height: 12),
              PQAction(label: s.tr('إعادة المزامنة', 'Retry sync'),
                onPressed: () async => _gameplayKey.currentState?.retryCompletion()),
            ] else ...[
              Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                _resultStat('coins_stack', result['coins_awarded']?.toString() ?? '—',
                  s.tr('عملات مكتسبة', 'Coins earned')),
                _resultStat('stars_three', '$rating / 3', s.tr('التقييم', 'Rating')),
                _resultStat('puzzle_piece', s.tr('الصورة', 'Picture'), s.tr('المجموعة', 'Collection')),
              ]),

            ],
          ]),
        )),
        )),
        if (!pending) Center(child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 390),
          child: Padding(padding: const EdgeInsets.fromLTRB(32, 8, 32, 12), child: Column(
                mainAxisSize: MainAxisSize.min, children: [
                PQAction(label: s.tr('المرحلة التالية', 'Next Level'), icon: Icons.play_arrow,
                  onPressed: () async {
                    try { await s.refreshCatalog(); } catch (_) {}
                    if (!mounted || level == null) return;
                    final levels = s.levels.where((item) => item.worldId == level.worldId).toList();
                    final index = levels.indexWhere((item) => item.id == level.id);
                    final next = index >= 0 && index + 1 < levels.length ? levels[index + 1] : null;
                    final canPlay = next?.unlocked == true;
                    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) =>
                      ScreenPage(session: s, id: canPlay ? 5 : 4,
                        extra: canPlay ? {'level': next!.id} : {'world': level.worldId})));
                  }),
                const SizedBox(height: 10),
                PQCTA(label: s.tr('إعادة اللعب', 'Replay'), icon: Icons.replay,
                  onPressed: level == null ? null : () async {
                    final confirmed = await showDialog<bool>(context: context, builder: (dialog) =>
                      PuzzleDialog(title: Text(s.tr('إعادة المرحلة؟', 'Replay this level?')), actions: [
                        TextButton(onPressed: () => Navigator.pop(dialog),
                          child: Text(s.tr('إلغاء', 'Cancel'))),
                        FilledButton(onPressed: () => Navigator.pop(dialog, true),
                          child: Text(s.tr('إعادة اللعب', 'Replay'))),
                      ]));
                    if (confirmed != true || !mounted) return;
                    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) =>
                      ScreenPage(session: s, id: 6, extra: {'level': level.id})));
                  }),
              ])),
        )),
      ]),
    ]);
  }

  Widget _resultStat(String art, String value, String label) => Flexible(child: Semantics(
    label: '$label: $value',
    child: Row(mainAxisSize: MainAxisSize.min, children: [
      Image.asset('assets/design/art/rewards/$art.png', width: 30, height: 30,
        fit: BoxFit.contain, excludeFromSemantics: true),
      const SizedBox(width: 4),
      Flexible(child: Text(value, style: const TextStyle(fontWeight: FontWeight.w700))),
    ]),
  ));

  final Map<String,Future<Map<String,dynamic>>> _queries={};
  Widget _data(String path,Widget Function(Map<String,dynamic>) builder){
    if(!s.authenticated)return PQEmpty(text:s.tr('سجّل الدخول أو تابع كضيف لعرض بياناتك','Sign in or play as guest to view your data'));
    return FutureBuilder<Map<String,dynamic>>(
      future:_queries.putIfAbsent(path,()=>s.api.get(path)),
      builder:(ctx,snapshot){
        if(snapshot.connectionState!=ConnectionState.done)return Center(child:PQInlineStatus(
          state:PQInlineState.loading,message:s.tr('جاري التحميل','Loading')));
        if(snapshot.hasError)return Center(child:PQInlineStatus(
          state:s.offline?PQInlineState.offline:PQInlineState.error,
          message:_errorText(snapshot.error!),onRetry:()=>_reload(path)));
        return builder(snapshot.data??{});
      },
    );
  }
  void _reload(String path) {
    if (!mounted) return;
    setState(() {
      _queries.remove(path);
    });
  }
  Widget _missions() => _data('missions', (data) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: _designTabs(s.tr('المهام', 'Missions'), s.tr('الأحداث', 'Events'),
          _showEvents, (value) => setState(() => _showEvents = value)),
      ),
      Expanded(child: ListView(
        key: PageStorageKey(_showEvents ? 'events-list' : 'missions-list'),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        children: [
          if (_showEvents)
            _previewPanel(minHeight: 96, child: Text(s.tr('لا توجد فعاليات متاحة حاليًا',
              'No events are available right now.')))
          else
            for (final raw in arr(data['missions'])) _missionCard(obj(raw)),
        ],
      )),
      Padding(padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: Material(color: Colors.transparent, borderRadius: BorderRadius.circular(16),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: () => _navigate(33),
            child: _previewPanel(minHeight: 96, child: Row(children: [
              _previewArt('treasure_chest', 64),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(s.tr('المكافأة اليومية', 'Daily Reward'), style: Theme.of(context).textTheme.titleLarge),
                Text(s.tr('اعرض تقويم المكافآت', 'View the reward calendar')),
              ])),
            ]))),
        ),
      ),
    ],
  ));

  Widget _missionCard(Map<String, dynamic> mission) {
    final progress = number(mission['progress']);
    final goal = number(mission['target']);
    final title = mission['name'] is Map ? localized(mission['name'], s.arabic)
        : '${mission['name'] ?? mission['id']}';
    return Padding(padding: const EdgeInsets.only(bottom: 10),
      child: _previewPanel(minHeight: 94, child: Column(children: [
        Row(children: [
          _previewArt('puzzle_piece', 48),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 6),
            Row(children: [
              Expanded(child: _designProgress(progress, goal)),
              const SizedBox(width: 8),
              Text('$progress / $goal', textDirection: TextDirection.ltr),
            ]),
          ])),
          const SizedBox(width: 10),
          Column(children: [
            _previewArt('coins_stack', 32),
            Text('+${number(mission['reward_coins'])}', textDirection: TextDirection.ltr),
          ]),
        ]),
        if (mission['claimed'] == true)
          Text(s.tr('تم استلام المكافأة', 'Reward claimed'),
            style: const TextStyle(color: PQColors.muted))
        else if (mission['eligible'] == true)
          TextButton.icon(icon:_previewArt('coins_stack',28),onPressed: () => _perform(() async {
            await s.mutate('missions/${mission['id']}/claim');
            if (mounted) _reload('missions');
          }), label: Text(s.tr('استلم المكافأة', 'Claim reward'))),
      ])),
    );
  }

  Widget _designTabs(String first, String second, bool secondSelected, ValueChanged<bool> onSelect) =>
    Container(decoration: BoxDecoration(color: PQColors.surface, borderRadius: BorderRadius.circular(24)),
      child: Row(children: [
        for (var index = 0; index < 2; index++)
          Expanded(child: TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(48, 48), foregroundColor: PQColors.white,
              backgroundColor: (index == 1) == secondSelected ? PQColors.purple : Colors.transparent),
            onPressed: () => onSelect(index == 1), child: Text(index == 0 ? first : second))),
      ]),
    );

  Widget _designProgress(int current, int total) => ClipRRect(borderRadius: BorderRadius.circular(8),
    child: LinearProgressIndicator(value: total <= 0 ? 0 : (current / total).clamp(0.0, 1.0),
      color: PQColors.actionGreen, backgroundColor: PQColors.background, minHeight: 10));

  Widget _collections() => _data('collections', (data) {
    final levels = s.levels.where((level) => level.worldId == 'green_valley' && level.published).toList();
    final confirmed = _completedLevelsFor(data);
    final collected = levels.where((level) => confirmed.contains(level.id)).length;
    return _scroll(_stack([
      _designTabs(s.tr('الصور', 'Pictures'), s.tr('الشارات', 'Badges'),
        _showBadges, (value) => setState(() => _showBadges = value)),
      const SizedBox(height: 16),
      if (_showBadges) ...[
        for (final entry in const [
          ['first_steps','First Steps'], ['green_valley_explorer','Green Valley Explorer'],
          ['perfect_solver','Perfect Solver'], ['star_collector','Star Collector'], ['puzzle_master','Puzzle Master'],
        ])
          PQCard(child: PQTrophyBadge(title: entry[1], criterion: entry[0],
            earned: arr(data['achievements']).contains(entry[0]))),
      ] else ...[
        GridView.count(crossAxisCount: 3, shrinkWrap: true, primary: false,
          physics: const NeverScrollableScrollPhysics(), mainAxisSpacing: 10, crossAxisSpacing: 10,
          children: [
            for (final level in levels) _collectionTile(level, confirmed.contains(level.id)),
          ]),
        const SizedBox(height: 20),
        _previewPanel(minHeight: 88, child: Row(children: [
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(s.tr('مجموعة الوادي الأخضر', 'Green Valley Collection'),
              style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            _designProgress(collected, levels.length),
            const SizedBox(height: 6),
            Text('$collected / ${levels.length}', textDirection: TextDirection.ltr),
          ])),
          IconButton(tooltip: s.tr('صندوق المكافأة', 'Reward Chest'), onPressed: () => _navigate(16),
            icon: _previewArt('treasure_chest', 58)),
        ])),
      ],
    ]));
  });

  Widget _collectionTile(LevelSpec level, bool collected) => Semantics(
    label: s.tr('المرحلة ${level.code}', 'Level ${level.code}'),
    child: Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: PQColors.surface, borderRadius: BorderRadius.circular(16),
        border: Border.all(color: collected ? PQColors.gold : PQColors.muted.withValues(alpha: .45), width: 2)),
      child: Stack(fit: StackFit.expand, children: [
        Opacity(opacity: collected ? 1 : .35, child: VerifiedLevelImage(level: level)),
        if (collected)
          const PositionedDirectional(end: 6, bottom: 6,
            child: Icon(Icons.check_circle, color: PQColors.success))
        else Center(child: _levelGridIcon('lock', 25)),
      ]),
    ),
  );

  Widget _leaderboard()=>_data('leaderboard/weekly',(data)=>_scroll(_stack([
    PQSectionTitle(text:s.tr('الترتيب العالمي الأسبوعي','Weekly Global Leaderboard')),
    PQCard(child:Text('${s.tr('بداية الموسم','Season starts')}: ${data['starts_at']??''}\n${s.tr('نهاية الموسم','Season ends')}: ${data['ends_at']??''}')),
    for(final (index,row) in arr(data['rows']).indexed)
      PQCard(child:ListTile(leading:CircleAvatar(backgroundColor:PQColors.gold,child:Text('${index+1}',style:const TextStyle(color:PQColors.background))),
        title:Text('${obj(row)['name']??''}'),subtitle:Text('⭐ ${number(obj(row)['stars'])}'),
        trailing:Text('${number(obj(row)['score'])}',style:const TextStyle(color:PQColors.gold)))),
    if(arr(data['rows']).isEmpty)PQEmpty(text:s.tr('لا يوجد ترتيب منشور بعد','No leaderboard results yet')),
    PQCard(child:Text(s.tr('الضيف والحساب الخاص لا يظهران في الترتيب العام.','Guest and private accounts are not listed publicly.'))),
  ])));
  Widget _shop()=>_data('shop',(data)=>_scroll(_stack([
    PQCard(child:Text('${s.tr('رصيدك','Balance')} 🪙 ${s.coins}  •  💡 ${s.hints}')),
    for(final item in arr(data['offers']))
      PQCard(child:PQWalletPurchase(
        title:'${obj(item)['id']}',price:number(obj(item)['price_coins']),
        availableCoins:s.coins,state:PQPurchaseState.confirm,
        onConfirm:()=>_confirmPurchase(obj(item)))),
    if(arr(data['offers']).isEmpty)PQEmpty(text:s.tr('لا توجد منتجات متاحة','No offers available')),
  ])));
  Future<void> _confirmPurchase(Map<String,dynamic> offer)async{
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>PuzzleDialog(
      title:Text(s.tr('تأكيد الشراء','Confirm purchase')),
      content:Text('${offer['id']} — ${offer['price_coins']} Coins'),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(s.tr('إلغاء','Cancel'))),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(s.tr('شراء','Buy')))],
    ));
    if(yes==true)await _perform(()async{await s.mutate('shop/purchases',{'offer_id':offer['id']});_reload('shop');});
  }
  Widget _profileSettings()=>_scroll(_stack([
    PQCard(child:ListTile(leading:const Icon(Icons.account_circle,size:44,color:PQColors.gold),
      title:Text(s.displayName),subtitle:Text(s.guest?s.tr('حساب ضيف','Guest account'):'${s.player['email']??''}'),
      onTap:()=>_navigate(26))),
    _menuItem(Icons.person,26,s.tr('حسابي','My Account')),
    _menuItem(Icons.emoji_events,34,s.tr('الإنجازات','Achievements')),
    _menuItem(Icons.leaderboard,10,s.tr('الترتيب','Leaderboard')),
    _menuItem(Icons.mail,35,s.tr('الرسائل','Inbox')),
    _menuItem(Icons.security,28,s.tr('الخصوصية','Privacy & Security')),
    _menuItem(Icons.help_center,36,s.tr('مركز المساعدة','Help Center')),
    _menuItem(Icons.settings,40,s.tr('خيارات الموافقات','Consent Options')),
    PQCard(child:PQLanguageSwitcher(arabic:s.arabic,onChanged:s.setLanguage)),
    PQCard(child:SwitchListTile(value:s.reduceMotion,
      title:Text(s.tr('تقليل الحركة','Reduce motion')),
      onChanged:s.setReduceMotion)),
    PQCard(child:SwitchListTile(value:s.soundEnabled,
      title:Text(s.tr('المؤثرات الصوتية','Sound effects')),
      onChanged:s.setSoundEnabled)),
    PQCard(child:SwitchListTile(value:s.hapticsEnabled,
      title:Text(s.tr('الاهتزاز عند التفاعل','Haptic feedback')),
      onChanged:s.setHapticsEnabled)),
    PQAction(label:s.tr('تسجيل الخروج','Log Out'),outlined:true,onPressed:()=>_perform(s.logout,next:18)),
  ]));
  Widget _menuItem(IconData icon,int target,String label)=>PQCard(child:ListTile(
    leading:Icon(icon,color:PQColors.gold),title:Text(label),trailing:const Icon(Icons.chevron_right),onTap:()=>_navigate(target)));
  Widget _gameOverlayInfo(String type)=>_scroll(_stack([
    PQCard(child:Text(s.tr('هذا الإجراء متاح أثناء المحاولة فقط ويُنفّذ من شاشة اللعب الحالية.','This action is available only during an active attempt through the gameplay screen.'))),
    PQAction(label:s.tr('العودة','Back'),onPressed:()=>Navigator.pop(context)),
  ]));
  Widget _chest()=>_scroll(_stack([
    Image.asset('assets/images/chest.png',height:180,errorBuilder:(context,error,stackTrace)=>const Icon(Icons.card_giftcard,size:120)),
    const PQSectionTitle(text:'300 Coins + 2 Hints'),
    PQCard(child:Text(s.tr('يُفتح مرة واحدة بعد إكمال المراحل الخمس وجمع 10 نجوم على الأقل.','Claim once after completing all five stages and earning at least ten stars.'))),
    PQAction(label:s.tr('استلام الصندوق','Claim Chest'),onPressed:()=>_perform(()async{await s.mutate('rewards/chest/claim');})),
  ]));
  Widget _village() => _data('village', (data) {
    final buildings = arr(data['buildings']).map(obj)
        .where((building) => const ['cottage', 'windmill'].contains(building['id'])).toList();
    if (buildings.isEmpty) return PQEmpty(text: s.tr('لا توجد مبانٍ', 'No buildings available'));
    final selected = _selectedBuilding ?? widget.extra['building'];
    final index = math.max(0, buildings.indexWhere((building) => building['id'] == selected));
    final building = buildings[index];
    final id = building['id'];
    final stage = number(building['stage']).clamp(0, 4).toInt();
    final upgrades = arr(building['transitions']).map(obj)
        .where((transition) => number(transition['from_stage']) == stage);
    final next = upgrades.isEmpty ? null : upgrades.first;
    final price = number(next?['price_coins']);
    return _scroll(_stack([
      const SizedBox(height: 22),
      _previewPanel(minHeight: 280, child: Column(children: [
        Text(id == 'cottage' ? s.tr('المنزل', 'Cottage') : s.tr('الطاحونة', 'Windmill'),
          style: Theme.of(context).textTheme.headlineSmall),
        Image.asset('assets/design/art/buildings/stages/${id}_stage_$stage.png',
          height: 230, fit: BoxFit.contain),
        Text(s.tr('الترميم $stage / 4', 'Restoration $stage / 4')),
      ])),
      const SizedBox(height: 16),
      if (next != null) ...[
        Text(s.tr('أكمل المرحلة ${next['requires_level_completed']} · $price عملة',
          'Complete level ${next['requires_level_completed']} · $price coins')),
        const SizedBox(height: 12),
      ],
      PQAction(label: s.tr('رمّم المبنى', 'Restore building'),
        onPressed: next == null || s.coins < price ? null : () => _perform(() async {
          await s.mutate('village/$id/upgrade', {'expected_stage': stage});
          if (mounted) _reload('village');
        })),
      if (buildings.length > 1) ...[
        const SizedBox(height: 12),
        PQAction(label: s.tr('المبنى التالي', 'Next building'), outlined: true,
          onPressed: () => setState(() => _selectedBuilding =
            buildings[(index + 1) % buildings.length]['id'] as String)),
      ],
    ]));
  });

  Widget _daily() => _data('rewards/daily', (data) {
    final calendar = arr(data['calendar']);
    final day = number(data['next_day']);
    final claimed = data['claimed_today'] == true;
    // The calendar GET reports the next day, including after today's claim.
    final claimedDay = claimed && day > 0 && day <= calendar.length
        ? (day == 1 ? calendar.length : day - 1)
        : null;
    final reward = day > 0 && day <= calendar.length ? obj(calendar[day - 1]) : null;
    final coins = number(reward?['coins']);
    return Stack(fit: StackFit.expand, children: [
      Image.asset('assets/images/celebrate.png', fit: BoxFit.cover, excludeFromSemantics: true),
      Center(child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 390),
        child: Column(children: [
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
            child: Column(children: [
              Text(s.tr('تقويم مكافآت ٧ أيام', '7-Day Reward Calendar'),
                textAlign: TextAlign.center, style: const TextStyle(
                  color: Color(0xFFFFDA69), fontWeight: FontWeight.bold, fontSize: 23)),
              const SizedBox(height: 24),
              _previewArt('treasure_chest', 160),
              const SizedBox(height: 24),
              GridView.count(
                crossAxisCount: 4, mainAxisSpacing: 8, crossAxisSpacing: 8,
                shrinkWrap: true, primary: false, physics: const NeverScrollableScrollPhysics(),
                children: [
                  for (final (index, raw) in calendar.indexed)
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: index + 1 == claimedDay ? const Color(0xFF245C45) : const Color(0xFF3C2C81),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: index + 1 == claimedDay
                            ? PQColors.success : index + 1 == day && !claimed
                              ? PQColors.gold : const Color(0xFF7770AF)),
                      ),
                      child: Center(child: FittedBox(fit: BoxFit.scaleDown, child: Column(children: [
                        Text(s.tr('يوم ${index + 1}', 'Day ${index + 1}'),
                          style: const TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        if (index + 1 == claimedDay)
                          Icon(Icons.check_circle, size: 22, color: PQColors.success,
                            semanticLabel: s.tr('تم الاستلام', 'Claimed'))
                        else if (index == 6) _levelRatingStar(22, earned: true)
                        else _previewArt('coins_stack', 22),
                        Text('${number(obj(raw)['coins'])}',
                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                        if (number(obj(raw)['hints']) > 0)
                          Text(s.tr('+${number(obj(raw)['hints'])} تلميح', '+${number(obj(raw)['hints'])} hints'),
                            style: const TextStyle(fontSize: 10)),
                      ]))),
                    ),
                ],
              ),
            ]),
          )),
          Padding(padding: const EdgeInsets.fromLTRB(32, 6, 32, 18),
            child: PQAction(style: PQActionStyle.gold,
              iconAsset:'assets/design/art/rewards/coins_stack.png',
              label: claimed ? s.tr('تم الاستلام اليوم', 'Claimed today')
                : reward == null ? s.tr('استلم مكافأة اليوم', 'Claim today')
                : s.tr('استلم $coins عملة', 'Claim $coins Coins'),
              onPressed: claimed || reward == null ? null : () => _perform(() async {
                await s.mutate('rewards/daily/claim');
                _reload('rewards/daily');
              })),
          ),
        ]),
      )),
    ]);
  });

  Widget _achievements()=>_data('collections',(data)=>_scroll(_stack([
    for(final achievement in const [
      ['first_steps','First Steps'],['green_valley_explorer','Green Valley Explorer'],
      ['perfect_solver','Perfect Solver'],['star_collector','Star Collector'],['puzzle_master','Puzzle Master']])
      PQCard(child:PQTrophyBadge(title:achievement[1],criterion:achievement[0],
        earned:arr(data['achievements']).contains(achievement[0]))),
  ])));
  Widget _inbox()=>_data('inbox',(data)=>_scroll(_stack([
    PQAction(label:s.tr('تحديد الكل كمقروء','Mark all as read'),onPressed:()=>_perform(()async{
      await s.mutate('inbox/read-all',{'snapshot_id':data['read_all_snapshot_id']});_reload('inbox');
    })),
    for(final message in arr(obj(data['messages'])['data']))
      PQCard(child:PQNotificationTile(
        title:'${obj(message)['title']??obj(message)['type']??''}',
        body:'${obj(message)['body']??''}',
        state:obj(message)['expired']==true?PQNotificationState.expired:
          obj(message)['read_at']!=null?PQNotificationState.read:PQNotificationState.unread,
        onOpen:()=>_perform(()async{
          await s.mutate('inbox/read',{'message_id':obj(message)['id']});_reload('inbox');
        }))),
    if(arr(obj(data['messages'])['data']).isEmpty)PQEmpty(text:s.tr('لا توجد إشعارات','No notifications yet')),
  ])));
  final _nameField=TextEditingController();
  final _emailField=TextEditingController();
  final _passwordField=TextEditingController();
  final _confirmPasswordField = TextEditingController();
  final _codeField=TextEditingController();
  final _titleField=TextEditingController();
  final _descriptionField=TextEditingController();
  bool _visiblePassword=false;
  bool _acceptedTerms=false,_confirmedAge=false;
  String _supportCategory="technical_issue";
  picker.XFile? _supportAttachment;
  String? _otpChallengeId;
  DateTime? _resendAvailableAt;
  Timer? _otpTicker;
  @override void initState(){super.initState();_showEvents = widget.extra['events'] == true;if(widget.id==21){
    _otpChallengeId="${obj(widget.extra['challenge'])['challenge_id']}";
    _resendAvailableAt=DateTime.now().add(const Duration(seconds:60));
    _otpTicker=Timer.periodic(const Duration(seconds:1),(_){if(mounted)setState((){});});
  }}
  int get _otpWait => _resendAvailableAt==null?0:math.max(0,_resendAvailableAt!.difference(DateTime.now()).inSeconds+1);
  @override void dispose(){
    _nameField.dispose();_emailField.dispose();_passwordField.dispose();_confirmPasswordField.dispose();
    _otpTicker?.cancel();_codeField.dispose();_titleField.dispose();_descriptionField.dispose();super.dispose();
  }
  Widget _field(String title,TextEditingController controller,{bool secret=false,int lines=1,
    TextInputType? keyboard}) => Padding(padding:const EdgeInsets.symmetric(vertical:7),child:TextField(
      controller:controller,maxLines:lines,obscureText:secret&&!_visiblePassword,
      keyboardType:keyboard,decoration:InputDecoration(labelText:title,
        suffixIcon:secret?IconButton(onPressed:()=>setState(()=>_visiblePassword=!_visiblePassword),
          icon:Icon(_visiblePassword?Icons.visibility_off:Icons.visibility)):null),
    ));
  Widget _signIn()=>_authLayout([
    const SizedBox(height:16),
    Center(child: Image.asset('assets/design/art/characters/hero_avatar.png', height:96)),
    const SizedBox(height:24),
    _field(s.tr('البريد الإلكتروني','Email'),_emailField,keyboard:TextInputType.emailAddress),
    _field(s.tr('كلمة المرور','Password'),_passwordField,secret:true),
    TextButton(onPressed:()=>_navigate(22),child:Text(s.tr('نسيت كلمة المرور؟','Forgot Password?'))),
    PQAction(label:s.tr('تسجيل الدخول','Sign In'),onPressed:()=>_perform(()async{
      final result=await s.login(_emailField.text.trim(),_passwordField.text);
      if(result['state']=='mandatory_email_otp'){
        _navigate(21,{'challenge':obj(result['challenge']),
          'email':_emailField.text.trim(),'purpose':'mandatory_login'});
      }else{if(s.previousGuestToken!=null)await _navigate(29);_home();}
    })),
    const SizedBox(height:10),PQAction(label:s.tr('المتابعة باستخدام Google (قيد التهيئة)','Google Login (setup pending)'),
      outlined:true,onPressed:()=>_notice(s.tr('يتطلب إعداد OAuth Client وتوافق رمز nonce على Android وiOS.','Native OAuth clients and nonce-compatible sign-in must be configured before Google login.'))),
    TextButton(onPressed:()=>_navigate(20),child:Text(s.tr('إنشاء حساب','Create Account'))),
  ]);
  Widget _register()=>_authLayout([
    const SizedBox(height:32),
    _field(s.tr('الاسم من 2 إلى 40 حرفًا','Name (2–40 characters)'),_nameField),
    _field(s.tr('البريد الإلكتروني','Email'),_emailField,keyboard:TextInputType.emailAddress),
    _field(s.tr('كلمة المرور (6–64 حرفًا)','Password (6–64 characters)'),_passwordField,secret:true),
    _field(s.tr('تأكيد كلمة المرور','Confirm password'), _confirmPasswordField, secret:true),
    PQCard(child:CheckboxListTile(value:_acceptedTerms,
      title:Text(s.tr('أوافق على شروط الاستخدام وسياسة الخصوصية','I agree to the Terms and Privacy Policy')),
      subtitle:Text(s.tr('هذه الموافقة لا تشمل إعلانات مخصصة أو تسويقًا','Does not grant personalized advertising or marketing consent')),
      onChanged:(v)=>setState(()=>_acceptedTerms=v??false))),
    PQCard(child:CheckboxListTile(value:_confirmedAge,
      title:Text(s.tr('أؤكد أن عمري 13 عامًا أو أكثر','I confirm I am 13 years of age or older')),
      onChanged:(v)=>setState(()=>_confirmedAge=v??false))),
    PQAction(label:s.tr('إنشاء حساب','Create Account'),onPressed:(!_acceptedTerms||!_confirmedAge)?null:()=>_perform(()async{
      if (_passwordField.text != _confirmPasswordField.text) {
        _notice(s.tr('كلمتا المرور غير متطابقتين', 'Passwords do not match'));
        return;
      }
      final result=await s.register(_nameField.text.trim(),_emailField.text.trim(),_passwordField.text,
        termsVersion:'v1',ageConfirmed:_confirmedAge,termsAccepted:_acceptedTerms);
      await _navigate(21,{'challenge':obj(result['verification']),
        'email':_emailField.text.trim(),'purpose':'email_verification'});
    })),
    TextButton(onPressed:()=>_navigate(19),child:Text(s.tr('لديك حساب؟','Already registered?'))),
  ]);
  Widget _otp(){final purpose='${widget.extra['purpose']??'email_verification'}';
    return _authLayout([
      _authArt('mail'),
      const SizedBox(height:16),
      Text('${s.tr('رمز من 6 أرقام أُرسل إلى','6-digit code sent to')} ${widget.extra['email']??''}'),
      TextField(controller:_codeField,keyboardType:TextInputType.number,
        maxLength:6,autofillHints:const [AutofillHints.oneTimeCode],
        inputFormatters:[FilteringTextInputFormatter.digitsOnly],
        decoration:InputDecoration(labelText:s.tr('رمز التحقق','Verification Code'))),
      PQAction(label:s.tr('تأكيد','Verify'),onPressed:_codeField.text.length!=6?null:()=>_perform(()async{
        await s.verifyOtp(_otpChallengeId??'',_codeField.text.trim(),purpose);_home();
      })),
      const SizedBox(height:8),
      PQAction(label:_otpWait>0?'${s.tr('إعادة الإرسال بعد','Resend in')} $_otpWait s':s.tr('إعادة إرسال الرمز','Resend code'),outlined:true,
        onPressed:_otpWait>0?null:()=>_perform(()async{
          final result=await s.requestOtp('${widget.extra['email']}',purpose);
          _otpChallengeId='${obj(result['challenge']).isNotEmpty?obj(result['challenge'])['challenge_id']:result['challenge_id']}';
          _resendAvailableAt=DateTime.now().add(const Duration(seconds:60));
          _codeField.clear();
        })) ,
      Text(s.tr('الرمز صالح 10 دقائق، وخمس محاولات كحد أقصى.','Code valid for 10 minutes, maximum five attempts.')),
    ]);
  }
  Widget _forgot()=>_authLayout([
    _authArt('mail'),
    const SizedBox(height:24),
    _field(s.tr('بريد الحساب','Account email'),_emailField,keyboard:TextInputType.emailAddress),
    PQAction(label:s.tr('إرسال رمز الاستعادة','Send Recovery Code'),onPressed:()=>_perform(()async{
      final challenge=await s.requestOtp(_emailField.text.trim(),'password_recovery');
      await _navigate(23,{'challenge':challenge,'email':_emailField.text.trim()});
    })),
  ]);
  Widget _reset()=>_authLayout([
    _field(s.tr('رمز البريد','Email Code'),_codeField,keyboard:TextInputType.number),
    _field(s.tr('كلمة المرور الجديدة','New Password'),_passwordField,secret:true),
    _field(s.tr('تأكيد كلمة المرور','Confirm password'), _confirmPasswordField, secret:true),
    PQAction(label:s.tr('تغيير كلمة المرور','Reset Password'),onPressed:()=>_perform(()async{
      if (_passwordField.text != _confirmPasswordField.text) {
        _notice(s.tr('كلمتا المرور غير متطابقتين', 'Passwords do not match'));
        return;
      }
      await s.resetPassword('${obj(widget.extra['challenge'])['challenge_id']}',_codeField.text.trim(),_passwordField.text);
    },next:19)),
  ]);
  Widget _guest()=>_authLayout([
    Center(child: _previewArt('puzzle_piece', 130)),
    PQCard(child:Text(s.tr('يمكنك اللعب بدون حساب. لا تُكرر مكافأة البداية عند التسجيل.','Play without an account. Initial bonuses cannot be duplicated when registering.'))),
    PQCard(child:CheckboxListTile(value:_confirmedAge,
      title:Text(s.tr('أؤكد أن عمري 13 عامًا أو أكثر','I confirm I am 13 or older')),
      onChanged:(v)=>setState(()=>_confirmedAge=v??false))),
    PQAction(label:s.tr('ابدأ كضيف','Start as Guest'),onPressed:!_confirmedAge?null:()=>_perform(
      ()=>s.startGuest(ageConfirmed:_confirmedAge),next:2)),
    const SizedBox(height:16),PQAction(label:s.tr('إنشاء حساب','Create Account'),outlined:true,onPressed:()=>_navigate(20)),
  ]);
  Widget _avatars()=>_scroll(_stack([
    const PQSectionTitle(text:'Choose Avatar'),
    for(final name in const ['explorer_boy_blue','explorer_boy_glasses','explorer_elder_scout',
      'explorer_elder_turquoise','explorer_girl_orange','explorer_girl_purple',
      'explorer_man_orange','explorer_woman_yellow'])
      PQCard(child:ListTile(leading:const Icon(Icons.face,color:PQColors.gold),title:Text(name),
        trailing:const Icon(Icons.check_circle_outline),
        onTap:()=>_perform(()async{await s.saveProfile({'avatar':name});},next:26))),
  ]));
  Widget _account()=>_scroll(_stack([
    PQCard(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      Text(s.displayName,style:Theme.of(context).textTheme.headlineSmall),
      Text('${s.player['email']??''}'),
      Text('⭐ ${s.stars}    🪙 ${s.coins}'),
    ])),
    _menuItem(Icons.edit,27,s.tr('تعديل الملف','Edit Profile')),
    _menuItem(Icons.face,25,s.tr('اختر شخصية','Choose Avatar')),
    _menuItem(Icons.security,28,s.tr('الخصوصية والأمان','Privacy & Security')),
    _menuItem(Icons.verified_user,40,s.tr('الموافقات','Consents')),
    if(s.guest)PQAction(label:s.tr('احفظ تقدم الضيف','Save Guest Progress'),onPressed:()=>_navigate(29)),
  ]));
  Widget _editProfile()=>_scroll(_stack([
    const PQSectionTitle(text:'Edit Profile'),
    _field(s.tr('اسم العرض','Display Name'),_nameField),
    PQAction(label:s.tr('حفظ الاسم','Save Name'),onPressed:()=>_perform(()async{
      await s.saveProfile({'name':_nameField.text.trim()});
    })),
    _menuItem(Icons.face,25,s.tr('تغيير الشخصية','Change Avatar')),
    PQCard(child:SwitchListTile(value:s.player['visibility']=='public',
      title:Text(s.tr('ملف عام','Public Profile')),
      subtitle:Text(s.tr('الافتراضي خاص','Private by default')),
      onChanged:(v)=>_perform(()async{await s.saveProfile({'visibility':v?'public':'private'});}))),
    const PQSectionTitle(text:'Preferred World'),
    for(final world in s.worlds)
      PQCard(child:ListTile(title:Text(localized(obj(world)['title'],s.arabic)),
        selected:s.player['preferred_world']==obj(world)['id'],
        onTap:()=>_perform(()async{await s.saveProfile({'preferred_world':obj(world)['id']});}))),
  ]));
  Widget _guestMerge()=>_scroll(_stack([
    PQCard(child:Text(s.tr('سيُدمج أفضل تقدم ونجوم وإنجازات الضيف مع الحساب. الرصيد النهائي يقرره الخادم دون مضاعفة مكافآت.','The server merges best progress and unique awards without duplicate balances.'))),
    PQAction(label:s.tr('تأكيد دمج التقدم','Confirm Smart Merge'),onPressed:s.previousGuestToken==null?null:
      ()=>_perform(s.mergeGuest,next:2)),
    const SizedBox(height:10),PQAction(label:s.tr('لاحقًا','Later'),outlined:true,onPressed:_home),
  ]));
  Future<bool> _reauth() async {
    if(s.guest){_notice(s.tr('التسجيل مطلوب','Registration required'));return false;}
    final method=await showDialog<String>(context:context,builder:(ctx)=>PuzzleDialog(
      title:Text(s.tr('إعادة التحقق من الهوية','Confirm your identity')),
      content:Text(s.tr('اختر كلمة المرور أو رمز تحقق عبر البريد الإلكتروني.','Use your password or an email verification code.')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(s.tr('إلغاء','Cancel'))),
        TextButton(onPressed:()=>Navigator.pop(ctx,'password'),child:Text(s.tr('كلمة المرور','Password'))),
        FilledButton(onPressed:()=>Navigator.pop(ctx,'otp'),child:const Text('Email OTP'))],
    ));
    if(method==null)return false;
    final field=TextEditingController();
    try {
      Map<String,dynamic>? challenge;
      if(method=='otp')challenge=await s.api.post('account/reauth/request',{},false);
      if(!mounted)return false;
      final result=await showDialog<String>(context:context,builder:(ctx)=>PuzzleDialog(
        title:Text(method=='otp'?s.tr('رمز البريد','Email OTP'):s.tr('كلمة المرور','Password')),
        content:TextField(controller:field,obscureText:method!='otp',
          keyboardType:method=='otp'?TextInputType.number:TextInputType.text,
          maxLength:method=='otp'?6:null,
          inputFormatters:method=='otp'?[FilteringTextInputFormatter.digitsOnly]:null,
          decoration:InputDecoration(labelText:method=='otp'?'OTP':s.tr('كلمة المرور','Password'))),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(s.tr('إلغاء','Cancel'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,field.text),child:Text(s.tr('تأكيد','Verify')))],
      ));
      if(result==null)return false;
      if(method=='otp'){
        await s.api.post('account/reauth/verify',{
          'challenge_id':'${challenge?['challenge_id']}','code':result,
        },false);
      } else {await s.api.post('account/reauth',{'password':result},false);}
      return true;
    }catch(e){_notice(_errorText(e));return false;}
    finally{field.dispose();}
  }
  Future<void> _changeEmail() async {
    if(!await _reauth() || !mounted){return;}
    final address=TextEditingController();
    final newEmail=await showDialog<String>(context:context,builder:(ctx)=>PuzzleDialog(
      title:Text(s.tr('البريد الإلكتروني الجديد','New email address')),
      content:TextField(controller:address,keyboardType:TextInputType.emailAddress,
        decoration:InputDecoration(labelText:s.tr('البريد الجديد','New email'))),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(s.tr('إلغاء','Cancel'))),
        FilledButton(onPressed:()=>Navigator.pop(ctx,address.text.trim()),child:Text(s.tr('إرسال OTP','Send OTP')))],
    ));
    address.dispose();
    if(newEmail==null||!newEmail.contains('@'))return;
    try {
      final request=await s.api.post('account/email/request',{'new_email':newEmail});
      if(!mounted)return;
      final code=TextEditingController();
      final confirmed=await showDialog<String>(context:context,builder:(ctx)=>PuzzleDialog(
        title:Text(s.tr('تحقق من بريدك الجديد','Verify your new email')),
        content:TextField(controller:code,keyboardType:TextInputType.number,
          maxLength:6,inputFormatters:[FilteringTextInputFormatter.digitsOnly],
          decoration:const InputDecoration(labelText:'OTP')),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(s.tr('إلغاء','Cancel'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,code.text),child:Text(s.tr('تأكيد','Confirm')))],
      ));
      code.dispose();
      if(confirmed==null||confirmed.length!=6)return;
      await s.api.post('account/email/confirm',{
        'challenge_id':'${request['challenge_id']}','code':confirmed,
      });
      await s.refreshPlayer();
      _notice(s.tr('تم تحديث البريد الإلكتروني','Email changed successfully'));
    } catch(e){_notice(_errorText(e));}
  }
  Widget _privacy()=>_scroll(_stack([
    const PQSectionTitle(text:'Privacy & Security'),
    PQCard(child:SwitchListTile(value:s.player['visibility']=='public',
      title:Text(s.tr('إظهار النتائج في الترتيب العام','Public Leaderboard Profile')),
      onChanged:(v)=>_perform(()async{await s.saveProfile({'visibility':v?'public':'private'});}))),
    PQAction(label:s.tr('تغيير البريد الإلكتروني','Change Email'),outlined:true,onPressed:_changeEmail),
    const PQSectionTitle(text:'Signed-in Devices'),
    _dataInlineDevices(),
    PQAction(label:s.tr('تسجيل خروج بقية الأجهزة','Log Out Other Devices'),outlined:true,onPressed:()=>_perform(()async{
      if(!await _reauth())return;
      await s.mutate('account/devices/revoke',{'others':true,'confirm':true});_reload('account/devices');
    })),
    const PQSectionTitle(text:'Export My Data'),
    PQAction(label:s.tr('طلب تصدير البيانات ZIP','Request Data Export ZIP'),outlined:true,onPressed:()=>_perform(()async{
      if(!await _reauth())return;
      await s.mutate('account/exports');_reload('account/exports');
    })),
    _exportList(),
    const SizedBox(height:16),_menuItem(Icons.delete_forever,30,s.tr('حذف الحساب','Delete Account')),
  ]));
  Widget _dataInlineDevices()=>_data('account/devices',(data)=>Column(children:[
    for(final d in arr(data['devices']))PQCard(child:ListTile(
      leading:Icon(obj(d)['is_current']==true?Icons.phone_iphone:Icons.devices,color:PQColors.gold),
      title:Text('${obj(d)['device_name']??obj(d)['platform']}'),
      subtitle:Text('${obj(d)['last_activity_at']??''}'),
      trailing:obj(d)['is_current']==true?Text(s.tr('هذا الجهاز','Current')):
        IconButton(icon:const Icon(Icons.logout),onPressed:()=>_perform(()async{
          if(!await _reauth())return;
          await s.mutate('account/devices/revoke',{'token_id':obj(d)['id'],'confirm':true});
          _reload('account/devices');
        })),
    )),
  ]));
  Widget _exportList()=>_data('account/exports',(data)=>Column(children:[
    for(final x in arr(data['exports']))PQCard(child:ListTile(
      leading:const Icon(Icons.archive_outlined),title:Text('${obj(x)['state']}'),
      subtitle:Text('${obj(x)['created_at']}'),
      // Bearer-authenticated download stays in the app; a system share sheet
      // is the only way to export its temporary ZIP to a user-chosen location.
      trailing:obj(x)['state']=='ready'?IconButton(
        icon:const Icon(Icons.download_for_offline),
        tooltip:s.tr('تنزيل ملف البيانات','Download personal data'),
        onPressed:()=>_downloadExport('${obj(x)['id']}'),
      ):const Icon(Icons.schedule),
    )),
    if(arr(data['exports']).isEmpty)Text(s.tr('لا توجد طلبات تصدير','No export requests')),
  ]));
  Future<void> _downloadExport(String id) async {
    try {
      final contents=await s.api.downloadPrivateZip(id);
      final temp=await getTemporaryDirectory();
      final file=File('${temp.path}/PuzzleQuest-personal-data-$id.zip');
      await file.writeAsBytes(contents,flush:true);
      try {
        await SharePlus.instance.share(ShareParams(
          files:[XFile(file.path,mimeType:'application/zip')],
          subject:'PuzzleQuest personal data export',
        ));
      } finally {
        if(await file.exists())await file.delete();
      }
      // The user chooses the export destination; no public URL contains a token.
    }catch(e){_notice(_errorText(e));}
  }
  Widget _deleteAccount()=>_scroll(_stack([
    const Icon(Icons.warning_amber_rounded,color:Colors.orange,size:76),
    PQCard(child:Text(s.tr('بعد التأكيد تُلغى الجلسات وتبدأ فترة استرجاع مدتها 30 يومًا، ثم يبدأ الحذف النهائي وفق السياسة القانونية.','After confirmation sessions are revoked; a 30-day recovery period applies before deletion.'))),
    PQAction(label:s.tr('طلب حذف حسابي','Request Account Deletion'),onPressed:()=>_perform(()async{
      if(!await _reauth() || !mounted){return;}
      final confirm=await showDialog<bool>(context:context,builder:(ctx)=>PuzzleDialog(
        title:Text(s.tr('تأكيد نهائي','Final Confirmation')),
        content:Text(s.tr('هل أنت متأكد من حذف الحساب؟','Are you sure you want to delete your account?')),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(s.tr('إلغاء','Cancel'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(s.tr('تأكيد الحذف','Delete')))],
      ));
      if(confirm==true){
        await s.api.post('account/deletion',{'confirmation':'DELETE','confirm':true});
        await s.logoutLocalAfterRevocation();
        if(mounted){Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder:(_)=>ScreenPage(session:s,id:18)),(_)=>false);}
      }
    })),
  ]));
  Widget _tutorial() {
    final steps = [
      (s.tr('حرّك القطع', 'Move the pieces'), s.tr('اسحب القطعة إلى موضعها الصحيح على اللوحة.',
        'Drag the piece to its correct place on the board.')),
      (s.tr('راقب الوقت', 'Watch the timer'), s.tr('يمكنك إيقاف اللعب مؤقتًا من قائمة الإيقاف.',
        'You can pause the game from the pause menu.')),
      (s.tr('أكمل الصورة', 'Complete the picture'), s.tr('تظهر المكافآت بعد تأكيد الخادم.',
        'Rewards appear after server confirmation.')),
    ];
    final (title, note) = steps[_tutorialStep];
    return _scroll(_stack([
      const SizedBox(height: 24),
      Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 20),
      ClipRRect(borderRadius: BorderRadius.circular(16), child: Image.asset(
        'assets/design/ui/tutorial/tutorial_${_tutorialStep + 1}.png',
        height: 208, fit: BoxFit.contain, excludeFromSemantics: true)),
      const SizedBox(height: 16),
      _previewPanel(minHeight: 88, child: Text(note)),
      const SizedBox(height: 24),
      PQAction(label: _tutorialStep == steps.length - 1 ? s.tr('فهمت', 'Got it') : s.tr('التالي', 'Next'),
        onPressed: () {
          if (_tutorialStep == steps.length - 1) {
            Navigator.maybePop(context);
          } else {
            setState(() => _tutorialStep++);
          }
        }),
      TextButton(onPressed: () => Navigator.maybePop(context), child: Text(s.tr('تخطي', 'Skip'))),
    ]));
  }
  Widget _support()=>_data('support/tickets',(data)=>_scroll(_stack([
    const PQSectionTitle(text:'Help & Support'),
    const PQCard(child:Text('info@50sols.com')),
    DropdownButtonFormField<String>(initialValue:_supportCategory,
      decoration:InputDecoration(labelText:s.tr('نوع المشكلة','Issue category')),
      items:const [
        DropdownMenuItem(value:'account_login',child:Text('Account & Login')),
        DropdownMenuItem(value:'gameplay_progress',child:Text('Gameplay & Progress')),
        DropdownMenuItem(value:'rewards_points',child:Text('Rewards & Points')),
        DropdownMenuItem(value:'ads',child:Text('Ads')),
        DropdownMenuItem(value:'privacy_data',child:Text('Privacy & Data')),
        DropdownMenuItem(value:'technical_issue',child:Text('Technical Issue')),
        DropdownMenuItem(value:'other',child:Text('Other')),
      ],onChanged:(v)=>setState(()=>_supportCategory=v??'technical_issue')),
    _field(s.tr('عنوان المشكلة','Issue title'),_titleField),
    _field(s.tr('وصف المشكلة','Description'),_descriptionField,lines:4),
    PQAction(label:_supportAttachment==null
       ? s.tr('إضافة صورة اختيارية','Attach optional image')
       : s.tr('تم اختيار الصورة • تغيير','Image selected • change'),
      outlined:true,onPressed:()async{
        try{
          final image=await picker.ImagePicker().pickImage(
            source:picker.ImageSource.gallery,imageQuality:78,maxWidth:1280,maxHeight:1280);
          if(image!=null && mounted)setState(()=>_supportAttachment=image);
        }catch(e){_notice(_errorText(e));}
      }),
    PQAction(label:s.tr('إرسال طلب دعم','Submit Support Ticket'),onPressed:()=>_perform(()async{
      final attachment=_supportAttachment;
      await s.api.multipartSupport(fields:{
        'category':_supportCategory,'title':_titleField.text.trim(),
        'description':_descriptionField.text.trim(),
      },image:await attachment?.readAsBytes(),filename:attachment?.name);
      _titleField.clear();_descriptionField.clear();_supportAttachment=null;
      _reload('support/tickets');
    })),
    const PQSectionTitle(text:'My Support Requests'),
    for(final item in arr(data['data']))PQCard(child:ListTile(
      title:Text('${obj(item)['title']}'),subtitle:Text('${obj(item)['state']}'),
      onTap:()=>_showTicket('${obj(item)['id']}'),
    )),
  ])));
  Future<void> _showTicket(String id) async {
    final reply=TextEditingController();
    try{
      final result=await s.api.get('support/tickets/$id');
      if(!mounted)return;
      final canReply=obj(result['ticket'])['state']!='closed';
      final replyText=await showDialog<String>(context:context,builder:(ctx)=>PuzzleDialog(
        title:Text('${obj(result['ticket'])['title']}'),
        content:SizedBox(width:450,child:SingleChildScrollView(child:Column(
          mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          Text('${obj(result['ticket'])['description']}'),
          for(final item in arr(result['replies']))PQCard(child:Text('${obj(item)['body']}')),
          if(canReply)TextField(controller:reply,minLines:2,maxLines:4,
            decoration:InputDecoration(labelText:s.tr('الرد على التذكرة','Reply to ticket'))),
        ]))),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(s.tr('إغلاق','Close'))),
          if(canReply)FilledButton(onPressed:()=>Navigator.pop(ctx,reply.text),
            child:Text(s.tr('إرسال رد','Send reply')))],
      ));
      if(replyText!=null&&replyText.trim().isNotEmpty){
        await s.mutate('support/tickets/$id/reply',{'body':replyText.trim()});
        _reload('support/tickets');
      }
    }catch(e){_notice(_errorText(e));}
    finally{reply.dispose();}
  }
  Widget _statusScreen({
    required String art, required String message, required String notice,
    required String actionLabel, required VoidCallback action,
    String? secondaryLabel, VoidCallback? secondary,
  }) => LayoutBuilder(builder: (context, bounds) {
    final compact = bounds.maxHeight < 640;
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      child: Center(child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 326, minHeight: math.max(0.0, bounds.maxHeight - 32)),
        child: Column(mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              SizedBox(height: compact ? 28 : 116),
              _authArt(art),
              SizedBox(height: compact ? 18 : 54),
              Text(message, textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _previewPanel(minHeight: 64, child: Text(notice, textAlign: TextAlign.center)),
              const SizedBox(height: 24),
            ]),
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              PQAction(label: actionLabel, onPressed: action),
              if (secondaryLabel != null) Padding(
                padding: const EdgeInsets.only(top: 8),
                child: TextButton(onPressed: secondary, child: Text(secondaryLabel)),
              ),
            ]),
          ]),
      )),
    );
  });

  Widget _connection() => _statusScreen(
    art: 'cloud',
    message: s.tr('انقطع الاتصال', 'Connection lost'),
    notice: s.tr('تقدمك المحلي محفوظ. المكافآت المعلّقة تحتاج تأكيد الخادم.',
      'Local progress is saved. Pending rewards require server confirmation.'),
    actionLabel: s.tr('إعادة المحاولة', 'Retry'),
    action: () {
      if (widget.extra['startup'] == true) {
        unawaited(s.initialize());
      } else {
        unawaited(_perform(s.refreshCatalog));
      }
    },
    secondaryLabel: s.authenticated && s.levels.isNotEmpty
        ? s.tr('عرض المراحل المحفوظة', 'View cached levels') : null,
    secondary: () => _navigate(3),
  );

  Widget _adUnavailable() => _statusScreen(
    art: 'video',
    message: s.tr('الفيديو غير متاح', 'Video unavailable'),
    notice: s.tr('تقدمك محفوظ. لم تُخصم عملات أو تُضف مكافأة.',
      'Your progress is saved. No coins were charged and no reward was granted.'),
    actionLabel: s.tr('متابعة اللعب', 'Continue playing'),
    action: () => Navigator.maybePop(context),
  );

  Widget _systemStates() => _statusScreen(
    art: 'info',
    message: s.tr('المحتوى غير متاح حاليًا', 'Content is unavailable'),
    notice: s.tr('جرّب العودة إلى الشاشة السابقة أو استكشف المراحل المتاحة.',
      'Return to the previous screen or explore the available levels.'),
    actionLabel: s.tr('استكشف المراحل', 'Explore levels'),
    action: () => _navigate(3),
  );

  bool _push=false,_personalizedAds=false,_consentLoaded=false;
  Widget _consent(){
    if(!_consentLoaded){
      final prefs=obj(s.player['preferences']);
      _push=prefs['push']==true;
      _personalizedAds=prefs['personalized_ads']==true;
      _consentLoaded=true;
    }
    return _scroll(_stack([
    const PQSectionTitle(text:'Privacy Consent'),
    PQCard(child:SwitchListTile(title:Text(s.tr('الإشعارات الاختيارية','Optional notifications')),
      value:_push,onChanged:(v)=>setState(()=>_push=v))),
    PQCard(child:SwitchListTile(title:Text(s.tr('إعلانات مخصصة','Personalized ads')),
      value:_personalizedAds,onChanged:(v)=>setState(()=>_personalizedAds=v))),
    PQCard(child:Text(s.tr('التتبع والتسويق والتحليلات غير الضرورية مغلقة افتراضيًا.','Non-essential tracking, marketing and analytics are off by default.'))),
    PQAction(label:s.tr('حفظ الخيارات','Save Choices'),onPressed:()=>_perform(()async{
      await s.mutate('account/consent',{
        'document_version':'v1','choices':{'notifications':_push,
          'personalized_ads':_personalizedAds,'terms_accepted':true},
      });
      try{await s.configurePush(_push);}
      catch(e){_notice(_errorText(e));}
    })),
  ]));
  }
  void _notice(String text) {
    if (mounted) unawaited(showPuzzleMessage(context, text));
  }
}


class _HomePlayShine extends StatefulWidget {
  const _HomePlayShine({required this.enabled, required this.child});

  final bool enabled;
  final Widget child;

  @override
  State<_HomePlayShine> createState() => _HomePlayShineState();
}

class _HomePlayShineState extends State<_HomePlayShine> with SingleTickerProviderStateMixin {
  late final AnimationController _sweep = AnimationController(
    vsync: this, duration: const Duration(seconds: 4),
  );

  @override
  void initState() {
    super.initState();
    if (widget.enabled) _sweep.repeat();
  }

  @override
  void didUpdateWidget(covariant _HomePlayShine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.enabled == oldWidget.enabled) return;
    if (widget.enabled) {
      _sweep.repeat();
    } else {
      _sweep.stop();
    }
  }

  @override
  void dispose() {
    _sweep.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.enabled) return widget.child;
    return Stack(children: [
      widget.child,
      Positioned.fill(child: IgnorePointer(child: Padding(
        padding: const EdgeInsets.all(4),
        child: ClipRRect(borderRadius: BorderRadius.circular(22),
          child: AnimatedBuilder(animation: _sweep, builder: (context, _) {
            final progress = (_sweep.value / .38).clamp(0.0, 1.0);
            return FractionalTranslation(
              translation: Offset((progress * 1.5 - .75).toDouble(), 0),
              child: const DecoratedBox(decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment(-1, -.7), end: Alignment(1, .7),
                  colors: [Colors.transparent, Colors.transparent, Color(0x65FFFFFF),
                    Colors.transparent, Colors.transparent],
                  stops: [0, .42, .5, .58, 1],
                ),
              )),
            );
          }),
        ),
      ))),
    ]);
  }
}


