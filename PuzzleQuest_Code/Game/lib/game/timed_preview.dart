import '../widgets/puzzle_dialog.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../core/session.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// Countdown uses visible foreground time only. Server entitlement is always
/// authoritative; app background sends pause, resume re-activates entitlement.
class TimedPreview extends StatefulWidget {
  const TimedPreview({super.key,required this.session,required this.attemptId,
    required this.entitlementId,required this.image,required this.remainingMs});
  final PuzzleSession session;
  final String attemptId,entitlementId;
  final Uint8List image;
  final int remainingMs;
  @override State<TimedPreview> createState()=>_TimedPreviewState();
}
class _TimedPreviewState extends State<TimedPreview> with WidgetsBindingObserver {
  late int _remaining;
  final Stopwatch _visible=Stopwatch();
  Timer? _timer;
  bool _paused=false,_saving=false,_closed=false;
  String? _error;
  int _lastCheckpointSecond=-1;
  String get _key=>'pq.active_preview.${widget.attemptId}';
  int get _left=>math.max(0,_remaining-_visible.elapsedMilliseconds);
  @override void initState(){
    super.initState();WidgetsBinding.instance.addObserver(this);
    _remaining=widget.remainingMs;_visible.start();
    _timer=Timer.periodic(const Duration(milliseconds:200),(_){
      if(!mounted||_paused||_saving)return;
      if(_left==0){_finish();}
      else {
        final second=_visible.elapsedMilliseconds~/1000;
        if(second>_lastCheckpointSecond && second>0){
          _lastCheckpointSecond=second;_checkpoint();
        } else {setState((){});}
      }
    });
    _save();
  }
  Future<void> _save()async{
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString(_key,jsonEncode({'id':widget.entitlementId,'remaining_ms':_left}));
  }
  @override void dispose(){WidgetsBinding.instance.removeObserver(this);_timer?.cancel();_visible.stop();super.dispose();}
  @override void didChangeAppLifecycleState(AppLifecycleState state){
    if(state==AppLifecycleState.paused||state==AppLifecycleState.hidden||state==AppLifecycleState.inactive){_background();}
    else if(state==AppLifecycleState.resumed){_foreground();}
  }
  /// Persist remaining foreground time periodically. The server owns the
  /// entitlement; reconnect errors must not leave an unlimited image preview.
  Future<void> _checkpoint() async {
    if (_paused||_saving||_closed)return;
    _saving=true;_visible.stop();
    final spent=_visible.elapsedMilliseconds;
    _remaining=math.max(0,_remaining-spent);_visible.reset();
    await _save();
    try{
      await widget.session.api.post('previews/${widget.entitlementId}/lifecycle',{
        'visible_elapsed_ms':spent,'action':'tick',
      });
      _error=null;
    }catch(e){_error='$e';_paused=true;}
    finally{
      _saving=false;
      if(!_paused&&!_closed){_lastCheckpointSecond=-1;_visible.start();}
      if(mounted)setState((){});
    }
  }
  Future<void> _background()async{
    if(_paused||_closed)return;
    // If a checkpoint is in flight it will finish with _paused=true, rather
    // than restarting the preview timer while iOS/Android are backgrounded.
    if(_saving){_paused=true;return;}
    _paused=true;
    _visible.stop();final spent=_visible.elapsedMilliseconds;
    _remaining=math.max(0,_remaining-spent);_visible.reset();
    await _save();
    try{
      await widget.session.api.post('previews/${widget.entitlementId}/lifecycle',{
        'visible_elapsed_ms':spent,'action':'pause',
      });
    }catch(e){if(mounted)setState(()=>_error='$e');}
  }
  Future<void> _foreground()async{
    if(!_paused||_closed)return;
    if(_saving){
      await Future<void>.delayed(const Duration(milliseconds:300));
      if(mounted)await _foreground();
      return;
    }
    _saving=true;
    try{
      final result=await widget.session.api.post('attempts/${widget.attemptId}/preview/activate',{
        'entitlement_id':widget.entitlementId,
      });
      _remaining=number(result['remaining_ms'],_remaining);
      _visible.reset();_visible.start();_paused=false;_error=null;
      _lastCheckpointSecond=-1;
      await _save();
    }catch(e){_error='$e';}
    finally{_saving=false;if(mounted)setState((){});}
  }
  Future<void> _finish()async{
    if(_saving||_closed)return;
    _saving=true;_visible.stop();
    final spent=_visible.elapsedMilliseconds;
    try{
      await widget.session.api.post('previews/${widget.entitlementId}/lifecycle',{
        'visible_elapsed_ms':spent,'action':'close',
      });
      _closed=true;
      await (await SharedPreferences.getInstance()).remove(_key);
      if(mounted)Navigator.of(context).pop();
    }catch(e){_error='$e';_paused=true;}
    finally{_saving=false;if(mounted)setState((){});}
  }
  @override Widget build(BuildContext context){
    final label=widget.session.tr;
    return PopScope(canPop:false,child:PuzzleDialog(showHeader:false,
      content:Padding(padding:const EdgeInsets.all(14),child:Column(mainAxisSize:MainAxisSize.min,children:[
        Text(label('معاينة الصورة','Image Preview'),style:Theme.of(context).textTheme.titleLarge),
        const SizedBox(height:10),
        AspectRatio(aspectRatio:1,child:Stack(fit:StackFit.expand,children:[
          Image.memory(widget.image,fit:BoxFit.contain),
          if(_paused)ColoredBox(color:PQColors.surface,
            child:Center(child:Text(label('المعاينة متوقفة حتى تأكيد الخادم','Preview paused until server confirmation'),
              textAlign:TextAlign.center))),
        ])),
        const SizedBox(height:8),
        Text('${(_left/1000).ceil()} s',style:Theme.of(context).textTheme.titleLarge?.copyWith(color:PQColors.gold)),
        if(_paused)Text(label('متوقف في الخلفية / في انتظار الاستئناف','Paused / awaiting resume')),
        if(_error!=null)Text(_error!,style:const TextStyle(color:Colors.orange)),
        if(_paused)TextButton(onPressed:_saving?null:_foreground,
          child:Text(label('إعادة محاولة الاستئناف','Retry preview resume'))),
        const SizedBox(height:8),
        PuzzlePopupButton(onPressed:_saving?null:_finish,child:Text(label('إغلاق المعاينة','Close Preview'))),
      ])),
    ));
  }
}
