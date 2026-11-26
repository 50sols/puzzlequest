import '../widgets/puzzle_dialog.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'package:crypto/crypto.dart';
import '../core/ads_service.dart';
import '../core/content.dart';
import '../core/models.dart';
import '../core/offline_journal.dart';
import '../core/session.dart';
import '../core/theme.dart';
import 'puzzle_board.dart';
import '../widgets/component_library.dart';
import 'timed_preview.dart';
import '../widgets/game_art_button.dart';

class PuzzleGameplay extends StatefulWidget {
  const PuzzleGameplay({super.key, required this.level, required this.session,
    required this.onCompleted, required this.onExit, this.onLocalCompleted, this.offlineTicket=false});
  final bool offlineTicket;
  final LevelSpec level;
  final PuzzleSession session;
  final void Function(Map<String,dynamic> result) onCompleted;
  final VoidCallback onExit;
  final VoidCallback? onLocalCompleted;
  @override State<PuzzleGameplay> createState()=>PuzzleGameplayState();
}
class PuzzleGameplayState extends State<PuzzleGameplay> with WidgetsBindingObserver {
  final ContentStore _content = ContentStore();
  final GlobalKey _boardDropKey = GlobalKey();
  final ScrollController _trayScroll = ScrollController();
  PuzzleManifest? _manifest;
  PuzzleBoardGame? _board;
  PlacementJournal? _journal;
  Map<String,Uint8List> _pieceImages = {};
  Uint8List? _master;
  String? _attemptId;
  bool _lifecyclePaused=false,_watchingAd=false;
  bool _pendingSave=false,_restoringPreview=false;
  bool _loading=true,_paused=false,_submitting=false,_finished=false,_offlineTicket=false,_exiting=false,_localComplete=false,_syncPending=false;
  String? _error;
  int _elapsed=0;
  final Stopwatch _stopwatch=Stopwatch();
  Timer? _ticker;
  String? _selected,_hintPieceId;
  List<String> _trayOrder=[];
  @override
  void initState(){super.initState();WidgetsBinding.instance.addObserver(this);_initialize();}
  @override
  void dispose(){WidgetsBinding.instance.removeObserver(this);_ticker?.cancel();_stopwatch.stop();_content.dispose();_trayScroll.dispose();super.dispose();}
  int get _activeMs=>_elapsed+_stopwatch.elapsedMilliseconds;
  int get _remaining=>math.max(0,widget.level.limit*1000-_activeMs);
  bool get _terminal=>_finished||_remaining<=0||_localComplete;
  List<PuzzlePieceSpec> get _remainingPieces {
    final list=_manifest?.pieces.where((p)=>!(_journal?.placed.contains(p.id)??false)).toList()??[];
    if(_trayOrder.isNotEmpty){list.sort((a,b){
      final ai=_trayOrder.indexOf(a.id),bi=_trayOrder.indexOf(b.id);
      return (ai<0?10000:ai).compareTo(bi<0?10000:bi);
    });}
    return list;
  }

  Future<void> _initialize() async {
    try{
      final manifest=await _content.manifest(widget.level);
      if(!manifest.valid||manifest.pieces.length!=widget.level.pieceCount)throw StateError('Invalid puzzle geometry');
      final images=<String,Uint8List>{};
      for(final piece in manifest.pieces){
        images[piece.id]=await _content.bytes(widget.level,piece.imagePath,
          bundledPath:widget.level.downloadable?null:widget.level.bundledPiece(piece));
      }
      final master=await _content.master(widget.level);
      // Restore an active server-authorized attempt; never mint a new attempt
      // on app restart when a resumable one already exists.
      final prefs=await SharedPreferences.getInstance();
      final activeKey='pq.active_attempt.${widget.level.id}';
      final storedId=prefs.getString(activeKey);
      Map<String,dynamic>? attempt;
      if(storedId!=null){
        try {
          final found=await widget.session.api.get('attempts/$storedId');
          if (found['state'] == 'completed') {
            await (await PlacementJournal.restore(storedId)).discardAfterServerConfirmation();
            await prefs.remove(activeKey);
            await prefs.remove('pq.attempt_snapshot.$storedId');
            await prefs.remove('pq.attempt_creation_op.${widget.level.id}');
          }
          if(found['state']=='playing'||found['state']=='paused') attempt=found;
        }catch(_){ /* The old journal remains untouched for recovery. */ }
      }
      if(attempt==null && storedId!=null && widget.offlineTicket){
        final cached=prefs.getString('pq.attempt_snapshot.$storedId');
        if(cached!=null){attempt=obj(jsonDecode(cached));}
      }
      if(attempt==null){
        final opKey='pq.attempt_creation_op.${widget.level.id}';
        final operation=prefs.getString(opKey)??const Uuid().v4();
        await prefs.setString(opKey,operation);
        attempt=await widget.session.api.postWithKey('attempts',{
          'level_id':widget.level.id,'offline':widget.offlineTicket,
        },operation);
        // Remove only after the attempt itself has been persisted below.
      }
      final activeAttempt = attempt;
      if (activeAttempt['state']=='completed' || activeAttempt['state']=='timed_out') {
        throw StateError('Previous attempt is already finished; return to levels to start a new one.');
      }
      final id='${activeAttempt['id']}';
      if(id=='null')throw const FormatException('Missing attempt id');
      await prefs.setString(activeKey,id);
      await prefs.remove('pq.attempt_creation_op.${widget.level.id}');
      if(activeAttempt['offline']==true)await prefs.setString('pq.attempt_snapshot.$id',jsonEncode(activeAttempt));
      final journal=await PlacementJournal.restore(id);
      journal.placed.addAll(arr(activeAttempt['placed_piece_ids']).map((e)=>'$e'));
      // Mount the Flame widget before restoring sprites. Waiting for add()
      // here blocks startup because the game has no mounted component tree.
      final game=PuzzleBoardGame(manifest,images,restoredPieces:
        manifest.pieces.where((p)=>journal.placed.contains(p.id)).toList());
      if(!mounted)return;
      setState((){
        _manifest=manifest;_pieceImages=images;_master=master;
        _attemptId=id;_journal=journal;_board=game;
        _loading=false;_elapsed=math.max(number(activeAttempt['elapsed_ms']),journal.elapsedMs);
        _offlineTicket=activeAttempt['offline']==true;
        _pendingSave=journal.events.isNotEmpty && activeAttempt['offline']!=true;
        _localComplete = _offlineTicket && manifest.pieces.every((piece) => journal.placed.contains(piece.id));
        _syncPending = _localComplete;
      });
      if(activeAttempt['state']=='paused' && activeAttempt['offline']!=true) {
        try{await widget.session.api.post('attempts/$id/clock',{'action':'resume'});}catch(_){}
      }
      if (_localComplete) {
        widget.onLocalCompleted?.call();
        unawaited(retryCompletion());
        return;
      }
      _stopwatch.start();
      if (_pendingSave) unawaited(_retryPendingSave());
      unawaited(_restorePreviewIfNeeded());
      _ticker=Timer.periodic(const Duration(milliseconds:300),(_){
        if(!mounted||_paused||_finished||_localComplete)return;
        if(_remaining==0){_fail();}else {setState((){});}
      });
    }catch(e){if(mounted)setState((){_loading=false;_error='$e';});}
  }
  /// An uncertain network reply is retried with the exact same event IDs.
  /// The backend returns its authoritative placement set; no reward is minted
  /// until the completed response is received.
  String _batchKey(List<Map<String,dynamic>> events) =>
    sha256.convert(utf8.encode(jsonEncode(events))).toString();

  Future<void> _retryPendingSave() async {
    if (_offlineTicket || _submitting || _journal==null || _attemptId==null ||
        _journal!.events.isEmpty || _finished) {return;}
    if (mounted) setState(()=>_submitting=true);
    try {
      final result=await widget.session.api.postWithKey(
        'attempts/$_attemptId/events',
        {'events':_journal!.events}, _batchKey(_journal!.events));
      await _handleServerEvents(result);
    } catch (_) {
      if (mounted) setState(()=>_pendingSave=true);
    } finally {
      if (mounted) setState(()=>_submitting=false);
    }
  }
  Future<void> _handleServerEvents(Map<String,dynamic> result) async {
    if (result['state']=='timed_out') {await _fail();return;}
    final acknowledged=arr(result['placed_piece_ids']).map((x)=>'$x').toSet();
    if (acknowledged.containsAll(_journal!.events.map((e)=>'${e['piece_id']}'))) {
      await _journal!.markAcknowledged();
      _pendingSave=false;
    } else { _pendingSave=true; }
    if (result['state']=='completed') {
      _stopwatch.stop();_finished=true;
      await _journal!.discardAfterServerConfirmation();
      await (await SharedPreferences.getInstance()).remove('pq.active_attempt.${widget.level.id}');
      if (mounted) widget.onCompleted(result);
    }
  }
  Future<void> _restorePreviewIfNeeded() async {
    if (_restoringPreview || _attemptId==null || _offlineTicket || !mounted) return;
    final prefs=await SharedPreferences.getInstance();
    final raw=prefs.getString('pq.active_preview.$_attemptId');
    if(raw==null)return;
    final saved=obj(jsonDecode(raw));
    final entitlement='${saved['id']??''}';
    if(entitlement.isEmpty)return;
    _restoringPreview=true;
    try {
      final activation=await widget.session.api.post(
        'attempts/$_attemptId/preview/activate',{'entitlement_id':entitlement});
      final left=number(activation['remaining_ms']);
      if(left>0 && mounted) {await _preview(left,entitlement);}
      else {await prefs.remove('pq.active_preview.$_attemptId');}
    } catch (_) {
      // Keep the entitlement until its server-confirmed status is known.
    } finally {_restoringPreview=false;}
  }
  Future<void> _fail() async {
    if(_finished)return;
    _stopwatch.stop();setState((){_finished=true;});
    await _journal?.persist();
    if(mounted) {await showDialog<void>(context:context,builder:(ctx)=>PuzzleDialog(
      title:Text(widget.session.tr('انتهى الوقت','Time is up')),
      content:Text(widget.session.tr('لم تكتمل الصورة. لا تُمنح مكافأة.','Puzzle not completed. No reward is earned.')),
      actions:[TextButton(onPressed:(){Navigator.pop(ctx);widget.onExit();},child:Text(widget.session.tr('الخروج','Exit')))],
    ));}
  }
  Future<void> retryCompletion() async {
    if (_submitting) return;
    if (_offlineTicket) {
      setState(() => _submitting = true);
      try {
        await _syncOffline();
      } finally {
        if (mounted) setState(() => _submitting = false);
      }
    } else {
      await _retryPendingSave();
    }
  }

  Future<bool> prepareToLeave() async {
    if (_exiting) return false;
    if (_submitting) {
      _showError(widget.session.tr('جارٍ حفظ القطع، انتظر لحظة.', 'Saving pieces. Please wait.'));
      return false;
    }
    _exiting = true;
    try {
      if (!_loading && _journal != null) await _pause(fromLifecycle: true);
      return mounted;
    } catch (error) {
      _exiting = false;
      _showError(error);
      return false;
    }
  }

  Future<void> _pause({bool fromLifecycle=false}) async {
    if(_paused||_finished)return;
    _stopwatch.stop();_elapsed=_activeMs; // stopwatch elapsed is captured below before reset
    _stopwatch.reset();
    setState(()=>_paused=true);
    if(_journal!=null){_journal!.elapsedMs=_elapsed;await _journal!.persist();}
    if(_attemptId!=null && !_offlineTicket){
      try{await widget.session.api.post('attempts/$_attemptId/clock',{'action':'pause'});}catch(_){ /* keep local pause journal */ }
    }
    if(fromLifecycle)_lifecyclePaused=true;
    if(!fromLifecycle&&mounted)_showPause();
  }
  Future<void> _resume() async {
    if(_finished)return;
    _lifecyclePaused=false;
    if(_attemptId!=null && !_offlineTicket){
      try{await widget.session.api.post('attempts/$_attemptId/clock',{'action':'resume'});}catch(_){/* retain local timing */}
    }
    _stopwatch.start();if(mounted)setState(()=>_paused=false);
  }
  @override
  void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.paused||state==AppLifecycleState.inactive||state==AppLifecycleState.hidden){
      _pause(fromLifecycle:true);
    } else if(state==AppLifecycleState.resumed&&_lifecyclePaused&&_paused&&!_finished&&!_watchingAd){
      // Resume only after foreground return; the app is never ticking in the background.
      _resume();
    }
  }
  Future<void> _syncOffline()async{
    if(_attemptId==null||_journal==null||!_offlineTicket)return;
    _stopwatch.stop();
    final elapsedMs=_activeMs;
    _journal!.elapsedMs=elapsedMs;await _journal!.persist();
    try{
      final result=await widget.session.api.post('attempts/$_attemptId/offline/sync',{
        'journal':_journal!.events,'elapsed_ms':elapsedMs,'allocations':[],
      });
      if(result['state']!='completed')throw StateError('Offline result not verified');
      _finished=true;_syncPending=false;
      await _journal!.discardAfterServerConfirmation();
      final prefs=await SharedPreferences.getInstance();
      await prefs.remove('pq.active_attempt.${widget.level.id}');
      await prefs.remove('pq.attempt_snapshot.$_attemptId');
      if(mounted)widget.onCompleted(result);
    }catch(e){_syncPending=true;if(mounted)setState((){});_showError(
      widget.session.tr('النتيجة تنتظر تحقق الخادم؛ لن تُمنح مكافأة الآن.','Result pending server verification; no reward has been granted.'));
    }
  }
  Future<void> _acceptPiece(PuzzlePieceSpec piece, Offset local, double boardWidth,
      {bool isDrag = false}) async {
    if (_paused || _terminal || _submitting || _journal == null ||
        _manifest == null || _journal!.placed.contains(piece.id)) return;
    final manifest = _manifest!;
    final candidate = local * (manifest.boardSize / boardWidth);
    final cell = manifest.boardSize / math.sqrt(manifest.pieces.length);
    // A drop reports the feedback's top-left. A tap aims at the cell center.
    final expected = isDrag
        ? Offset(piece.target[0], piece.target[1])
        : Offset(piece.anchor[0] + cell / 2, piece.anchor[1] + cell / 2);
    if ((candidate - expected).distance > manifest.threshold) {
      if(widget.session.hapticsEnabled)unawaited(HapticFeedback.selectionClick());
      _showError(widget.session.tr('قرّب القطعة من موضعها الصحيح','Move the piece closer to its correct position'));
      return;
    }
    setState(()=>_submitting=true);
    try{
      _journal!.elapsedMs = _activeMs;
      await _journal!.add(piece);
      await _board!.place(piece);
      if(_hintPieceId==piece.id)_hintPieceId=null;
      if(widget.session.hapticsEnabled)unawaited(HapticFeedback.lightImpact());
      if(widget.session.soundEnabled)unawaited(SystemSound.play(SystemSoundType.click));
      if (_remainingPieces.isEmpty) {
        _localComplete = true;
        _stopwatch.stop();
        if (mounted) widget.onLocalCompleted?.call();
      }
      // Offline ticket: journal only; send when all pieces are placed.
      if(_offlineTicket){
        if(_remainingPieces.isEmpty){_localComplete=true;await _syncOffline();}
        return;
      }
      // Always save event before sending. Server ACK is authoritative.
      final response=await widget.session.api.postWithKey(
        'attempts/$_attemptId/events',{'events':_journal!.events},
        _batchKey(_journal!.events));
      await _handleServerEvents(response);
    }catch(e){
      _pendingSave=true;
      // Never award locally on uncertain network result. Preserve all journal data.
      _showError(widget.session.tr('الحفظ معلّق. سنحتفظ بمحاولتك على الجهاز.',
        'Save pending; your attempt is preserved locally.'));
    }finally{if(mounted)setState(()=>_submitting=false);}
  }
  Future<void> _showPause() async {
    if(!mounted)return;
    await showPuzzleSheet<void>(context:context,isScrollControlled:true,backgroundColor:PQColors.surface,
      builder:(modal)=>SafeArea(child:Padding(padding:const EdgeInsets.all(22),child:Column(
        mainAxisSize:MainAxisSize.min,children:[
          Text(widget.session.tr('إيقاف مؤقت','Paused'),style:Theme.of(modal).textTheme.headlineSmall),
          const SizedBox(height:16),
          PuzzlePopupButton(onPressed:()=>Navigator.pop(modal),child:Text(widget.session.tr('استئناف','Resume'))),
          const SizedBox(height:8),
          ListTile(leading:const Icon(Icons.shuffle),title:Text(widget.session.tr('خلط القطع','Shuffle')),
            subtitle:Text('${widget.session.tr('المخزن','Stored')}: ${widget.session.shuffles} — 150 Coins'),
            onTap:()async{Navigator.pop(modal);await _shuffle();}),
          ListTile(leading:const Icon(Icons.restart_alt),title:Text(widget.session.tr('إعادة المحاولة','Restart')),
            onTap:()async{
              final confirmed=await showDialog<bool>(context:modal,builder:(ctx)=>PuzzleDialog(
                title:Text(widget.session.tr('إعادة المرحلة؟','Restart level?')),
                content:Text(widget.session.tr('ستبدأ محاولة جديدة؛ لا تكرر مكافأة مكتسبة.','A new attempt will start. Rewards are not duplicated.')),
                actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
                  FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Restart'))],
              ));
              if(confirmed==true && mounted && modal.mounted){_exiting=true;Navigator.pop(modal); await _restart();}
            }),
          ListTile(leading:const Icon(Icons.exit_to_app),title:Text(widget.session.tr('خروج','Exit')),
            onTap:(){_exiting=true;Navigator.pop(modal);widget.onExit();}),
        ],
      ))));
    if(mounted&&!_finished&&!_exiting&&_paused)await _resume();
  }
  Future<void> _restart() async {
    _stopwatch.stop();_stopwatch.reset();
    _ticker?.cancel();
    final prefs=await SharedPreferences.getInstance();
    await prefs.remove('pq.active_attempt.${widget.level.id}');
    if(!mounted)return;
    setState((){
      _loading=true;_error=null;_board=null;_journal=null;_attemptId=null;
      _master=null;_manifest=null;_pieceImages={};_selected=null;_hintPieceId=null;
      _trayOrder=[];_elapsed=0;
      _finished=false;_paused=false;_exiting=false;_localComplete=false;_syncPending=false;_pendingSave=false;
    });
    await _initialize();
  }
  Future<void> _shuffle() async {
    if(_remainingPieces.length<2)return;
    final buy=widget.session.shuffles==0;
    if(buy){
      final confirmed=await showDialog<bool>(context:context,builder:(ctx)=>PuzzleDialog(
        title:Text(widget.session.tr('شراء خلط','Buy Shuffle')),
        content:Text(widget.session.tr('خصم 150 عملة عند نجاح الخلط فقط.','150 Coins charged only on successful shuffle.')),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:Text(widget.session.tr('إلغاء','Cancel'))),
          FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:Text(widget.session.tr('تأكيد','Confirm')))],
      ));if(confirmed!=true)return;
    }
    try{final shuffled=await widget.session.mutate('attempts/$_attemptId/assistance',{
      'type':'shuffle','confirm_purchase':buy,
    });setState((){_selected=null;_trayOrder=arr(shuffled['tray_order']).map((x)=>'$x').toList();});}
    catch(e){_showError(e);}
  }
  Future<void> _hint() async {
    if(_terminal)return;
    try{
      final r=await widget.session.mutate('attempts/$_attemptId/assistance',{'type':'hint'});
      final pieceId='${r['piece_id']}';_hintPieceId=pieceId;setState((){});
      final piece=_manifest!.pieces.firstWhere((p)=>p.id==pieceId);
      if(mounted) {showDialog<void>(context:context,builder:(ctx)=>PuzzleDialog(
        title:Text(widget.session.tr('تلميح','Hint')),
        content:Text('${widget.session.tr('القطعة','Piece')}: ${piece.id} — (${piece.anchor[0].round()}, ${piece.anchor[1].round()})'),
        actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('OK'))],
      ));}
    }catch(e){
      if(widget.session.hints==0 && _attemptId!=null){
        await _rewardedHint();
      }else{_showError(e);}
    }
  }
  Future<void> _rewardedHint() async {
    if(_attemptId==null)return;
    final yes=await showDialog<bool>(context:context,builder:(ctx)=>PuzzleDialog(
      title:Text(widget.session.tr('تلميح من إعلان','Rewarded Hint')),
      content:Text(widget.session.tr('هل تريد مشاهدة إعلان اختياري للحصول على تلميح واحد؟','Watch an optional ad to earn one hint?')),
      actions:[TextButton(onPressed:()=>Navigator.pop(ctx,false),child:const Text('Cancel')),
        FilledButton(onPressed:()=>Navigator.pop(ctx,true),child:const Text('Watch'))],
    ));
    if(yes!=true)return;
    _watchingAd=true;
    await _pause(fromLifecycle:true);
    try{await RewardedAdsService(widget.session).showRewarded(attemptId:_attemptId!,kind:'hint');}
    catch(e){_showError(e);}
    finally{_watchingAd=false;await _resume();}
  }
  Future<void> _showFullImage() async {
    final choice=await showPuzzleSheet<String>(context:context,backgroundColor:PQColors.surface,
      builder:(ctx)=>SafeArea(child:Column(mainAxisSize:MainAxisSize.min,children:[
        ListTile(title:Text(widget.session.tr('استخدام عرض 30 ثانية','Use 30-second preview')),
          subtitle:Text('${widget.session.fullImages} ${widget.session.tr('استخدام متاح','available')}'),onTap:()=>Navigator.pop(ctx,'paid')),
        ListTile(title:Text(widget.session.tr('مشاهدة إعلان 10 ثوانٍ','Watch ad for 10 seconds')),
          subtitle:Text(widget.session.tr('يتطلب تحقق Google AdMob','Google AdMob verification required')),
          onTap:()=>Navigator.pop(ctx,'ad')),
        TextButton(onPressed:()=>Navigator.pop(ctx),child:Text(widget.session.tr('إلغاء','Cancel'))),
      ])));
    if(choice=='paid'){
      try{
        final result=await widget.session.mutate('attempts/$_attemptId/preview/activate',{});
        await _preview(number(result['remaining_ms'],30000),'${result['id']}');
      }catch(e){_showError(e);}
    }else if(choice=='ad'){
      // Only the actual ad pauses the game; the subsequent 10-second image
      // preview does not pause gameplay. No local reward before Google SSV.
      _watchingAd=true;
      await _pause(fromLifecycle:true);
      try {
        final status=await RewardedAdsService(widget.session).showRewarded(attemptId:_attemptId!,kind:'full_image');
        if (status['test_ad'] == true) return;
        final entitlements=arr(status['entitlements']);
        final usable=entitlements.where((e)=>obj(e)['state']=='granted' && obj(e)['source']=='rewarded');
        if(usable.isEmpty)throw StateError('Verified preview entitlement not yet available');
        final entitlementId='${obj(usable.first)['id']}';
        final activated=await widget.session.api.post('attempts/$_attemptId/preview/activate',{
          'entitlement_id':entitlementId,
        });
        
        _watchingAd=false;
        await _resume();
        await _preview(number(activated['remaining_ms'],10000),entitlementId);
      }catch(e){_showError(e);} finally {
        if(_watchingAd){_watchingAd=false;await _resume();}
      }
    }
    // The active gameplay clock continues during the image preview itself.
  }
  Future<void> _preview(int remainingMs,String entitlementId) async {
    if(_master==null||!mounted||_attemptId==null)return;
    await showDialog<void>(context:context,barrierDismissible:false,builder:(ctx)=>TimedPreview(
      session:widget.session,attemptId:_attemptId!,entitlementId:entitlementId,
      image:_master!,remainingMs:remainingMs,
    ));
  }
  void _showError(Object error) {
    if (!mounted) return;
    final message = error is String ? error : widget.session.tr(
      'تعذّر إتمام العملية. حاول مرة تانية.', 'Couldn’t complete the action. Please try again.');
    unawaited(showPuzzleMessage(context, message, warning: true));
  }
  @override
  Widget build(BuildContext context){
    final s=widget.session;
    if(_loading) {return const Center(child:CircularProgressIndicator());}
    if(_error!=null) {return Center(child:Column(mainAxisSize:MainAxisSize.min,children:[
      Text(_error!,textAlign:TextAlign.center),
      const SizedBox(height:16),FilledButton(onPressed:widget.onExit,child:Text(s.tr('العودة','Back'))),
    ]));}
    final manifest=_manifest!;final board=_board!;
    return PopScope(canPop:false,onPopInvokedWithResult:(didPop,result){if(!didPop)_pause();},child:Column(children:[
      Padding(padding: const EdgeInsets.fromLTRB(8, 8, 16, 6), child: Row(children: [
        BackButton(onPressed: _paused || _finished ? null : () => _pause()),
        Expanded(child: Text('${s.tr('المرحلة', 'Level')} ${widget.level.code}',
          maxLines: 1, overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold))),
        Semantics(label: s.tr('القطع المثبتة', 'Placed pieces'),
          child: Text('${_journal!.placed.length}/${manifest.pieces.length}')),
        const SizedBox(width: 10),
        PQHUDTimer(remaining: Duration(milliseconds: _remaining),
          state: _remaining == 0 ? PQTimerState.expired
            : _lifecyclePaused ? PQTimerState.background
            : _paused ? PQTimerState.paused : PQTimerState.running,
          label: s.tr('الوقت المتبقي', 'Time remaining')),
      ])),
      Expanded(child:LayoutBuilder(builder:(ctx,constraints){
        final width = math.max(1.0, math.min(constraints.maxWidth - 24, constraints.maxHeight - 12));
        return Center(child:SizedBox(width:width,height:width,child:LayoutBuilder(builder:(boardContext,box){
          return DragTarget<String>(
            key: _boardDropKey,
            onWillAcceptWithDetails:(details)=>!_paused&&!_terminal,
            onAcceptWithDetails:(details){
              final render = _boardDropKey.currentContext?.findRenderObject() as RenderBox?;
              if(render==null)return;
              final local=render.globalToLocal(details.offset);
              final matches=manifest.pieces.where((p)=>p.id==details.data);
              if(matches.isNotEmpty)_acceptPiece(matches.first, local, render.size.width, isDrag: true);
            },
            builder:(ctx,candidates,rejected)=>GestureDetector(
              onTapUp:(evt){
                if(_selected==null)return;
                final matches=manifest.pieces.where((p)=>p.id==_selected);
                if(matches.isNotEmpty)_acceptPiece(matches.first,evt.localPosition,box.maxWidth);
              },
              child:ClipRRect(borderRadius:BorderRadius.circular(14),child:Stack(fit:StackFit.expand,children:[
                const ColoredBox(color: Color(0xFF191842)),
                if (_master != null)
                  IgnorePointer(child: Opacity(opacity: .25,
                    child: Image.memory(_master!, fit: BoxFit.fill,
                      gaplessPlayback: true, excludeFromSemantics: true))),
                GameWidget(game:board),
                if(_hintPieceId!=null)...[
                  Builder(builder:(context){
                    final piece=manifest.pieces.where((p)=>p.id==_hintPieceId);
                    if(piece.isEmpty)return const SizedBox();
                    final p=piece.first;
                    final boardCell=manifest.boardSize/math.sqrt(manifest.pieces.length);
                    return Positioned(
                      left:((p.anchor[0]+boardCell/2)/manifest.boardSize)*box.maxWidth-15,
                      top:((p.anchor[1]+boardCell/2)/manifest.boardSize)*box.maxWidth-15,
                      child:IgnorePointer(child:Container(width:30,height:30,
                        decoration:BoxDecoration(shape:BoxShape.circle,border:Border.all(color:PQColors.gold,width:3),
                          boxShadow:const [BoxShadow(color:PQColors.gold,blurRadius:18)]))),
                    );
                  }),
                ],
                IgnorePointer(child: DecoratedBox(decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: candidates.isNotEmpty ? PQColors.gold : PQColors.white, width: 2),
                ))),
                if(_submitting)const Positioned(right:4,top:4,child:CircularProgressIndicator(strokeWidth:2)),
              ])),
            ),
          );
        })));
      })),
      SizedBox(height: 100, child: Directionality(textDirection: TextDirection.ltr, child: Row(children: [
        IconButton(tooltip: s.tr('القطع السابقة', 'Previous pieces'),
          onPressed: () => _moveTray(-1), icon: const Icon(Icons.chevron_left_rounded, size: 32)),
        Expanded(child: ListView.builder(controller: _trayScroll, scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount:_remainingPieces.length,itemBuilder:(ctx,index){
          final piece=_remainingPieces[index];
          final image=_pieceImages[piece.id]!;
          final sourceSize = Size(piece.target[2], piece.target[3]);
          double imageScale() {
            final render = _boardDropKey.currentContext?.findRenderObject() as RenderBox?;
            return render == null ? 82 / sourceSize.longestSide : render.size.width / manifest.boardSize;
          }
          return Padding(padding:const EdgeInsets.symmetric(horizontal:5),child:Draggable<String>(
            data: piece.id,
            affinity: Axis.vertical,
            maxSimultaneousDrags: _paused || _terminal || _submitting ? 0 : 1,
            dragAnchorStrategy: (draggable, context, globalPosition) {
              final tray = context.findRenderObject()! as RenderBox;
              final fitted = applyBoxFit(BoxFit.contain, sourceSize, tray.size).destination;
              final origin = Alignment.center.inscribe(fitted, Offset.zero & tray.size).topLeft;
              final grab = tray.globalToLocal(globalPosition) - origin;
              final scale = imageScale();
              return Offset(grab.dx * sourceSize.width / fitted.width * scale,
                  grab.dy * sourceSize.height / fitted.height * scale);
            },
            feedback: Builder(builder: (context) {
              final scale = imageScale();
              return Image.memory(image, width: sourceSize.width * scale,
                height: sourceSize.height * scale, fit: BoxFit.fill);
            }),
            childWhenDragging:const SizedBox(width:76,height:76),
            child:SizedBox(width:78,height:76,child:PQPuzzlePieceView(
              image:image,label:'${s.tr('قطعة','Piece')} ${piece.id}',
              state:PQPieceState.idle,selected:_selected==piece.id,
              reduceMotion:s.reduceMotion,
              onSelect:()=>setState(()=>_selected=piece.id))),
          ));
        })),
        IconButton(tooltip: s.tr('القطع التالية', 'Next pieces'),
          onPressed: () => _moveTray(1), icon: const Icon(Icons.chevron_right_rounded, size: 32)),
      ]))),
      if(_pendingSave && !_offlineTicket)Padding(padding:const EdgeInsets.symmetric(horizontal:14),child:PQActionLocal(
        label:widget.session.tr('إعادة محاولة حفظ القطع','Retry Piece Sync'),onPressed:_retryPendingSave)),
      if(_syncPending)Padding(padding:const EdgeInsets.symmetric(horizontal:14),child:PQActionLocal(
        label:widget.session.tr('إعادة محاولة مزامنة النتيجة','Retry Result Sync'),onPressed:_syncOffline)),
      const SizedBox(height:10),
      Padding(padding: const EdgeInsets.fromLTRB(12, 0, 12, 12), child: Row(children: [
        Expanded(child: _gameTool(s.tr('تلميح', 'Hint'), 'art/rewards/hint_bulb.png',
          _hint, badge: s.hints)),
        const SizedBox(width: 8),
        Expanded(child: _gameTool(s.tr('الصورة كاملة', 'Full image'), 'ui/icons/video.png',
          _showFullImage, highlighted: true)),
        const SizedBox(width: 8),
        Expanded(child: _gameTool(s.tr('إيقاف', 'Pause'), 'ui/icons/pause.png', () => _pause())),
      ])),
    ]));
  }

  void _moveTray(int direction) {
    if (!_trayScroll.hasClients) return;
    final position = _trayScroll.position;
    final target = (position.pixels + direction * position.viewportDimension * .85)
        .clamp(position.minScrollExtent, position.maxScrollExtent).toDouble();
    if (widget.session.reduceMotion || MediaQuery.disableAnimationsOf(context)) {
      _trayScroll.jumpTo(target);
    } else {
      unawaited(_trayScroll.animateTo(target,
        duration: const Duration(milliseconds: 220), curve: Curves.easeOut));
    }
  }

  Widget _gameTool(String label, String art, VoidCallback onTap,
      {bool highlighted = false, int badge = 0}) {
    final name = art.contains('hint') ? 'hint' : art.contains('pause') ? 'pause' : 'full_image';
    final crop = switch(name) {
      'pause' => const Rect.fromLTRB(.16,.26,.84,.74),
      'hint' => const Rect.fromLTRB(.06,.15,.94,.85),
      _ => const Rect.fromLTRB(.01,.29,.99,.72),
    };
    return GameArtButton(asset:'assets/ui/buttons/${name}_art.png',label:label,
      crop:crop,badge:badge,onPressed:_paused||_terminal?null:onTap);
  }

}

class PQActionLocal extends StatelessWidget {
  const PQActionLocal({super.key,required this.label,required this.onPressed});
  final String label;final VoidCallback onPressed;
  @override Widget build(BuildContext context)=>FilledButton(onPressed:onPressed,child:Text(label));
}
