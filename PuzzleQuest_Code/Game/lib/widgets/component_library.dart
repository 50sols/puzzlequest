import 'dart:async';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/theme.dart';

/// DOC 03 / 08 component states. Presentation never modifies balances,
/// progression, advertising entitlements, or server-authoritative results.
enum PQActionStyle { primary, affirmative, secondary, destructive, gold }
enum PQTimerState { running, paused, background, expired }
enum PQCurrencyState { settled, pending, insufficient }
enum PQLevelState { locked, available, completed, perfect }
enum PQPieceState { idle, dragging, nearSlot, correct, wrong }
enum PQBoardState { loading, interactive, paused, complete }
enum PQPurchaseState { checking, confirm, success, declined }
enum PQRewardState { loading, collectible, claimed }
enum PQAdState { eligible, unavailable, loading, verified, canceled }
enum PQBuildingState { ruined, ready, insufficient, upgrading, completed }
enum PQMissionState { open, progress, claimable, claimed }
enum PQNotificationState { unread, read, expired }
enum PQInlineState { loading, empty, offline, error }

/// Buttons use the *owner-approved PNG* button-state family, not a substitute
/// Flutter gradient. Nine-slicing avoids stretching art corners.
class PQCTA extends StatefulWidget {
  const PQCTA({super.key,required this.label,required this.onPressed,
    this.style=PQActionStyle.primary,this.icon,this.iconAsset,this.loading=false,
    this.semanticLabel,this.reduceMotion=false});
  final String label;
  final FutureOr<void> Function()? onPressed;
  final PQActionStyle style;
  final IconData? icon;
  final String? iconAsset;
  final bool loading, reduceMotion;
  final String? semanticLabel;
  @override State<PQCTA> createState()=>_PQCTAState();
}

class _PQCTAState extends State<PQCTA> {
  bool _busy=false,_pressed=false,_focused=false;
  bool get _disabled=>widget.onPressed==null || widget.loading || _busy;
  String get _family=>switch(widget.style){
    PQActionStyle.primary=>'primary',
    PQActionStyle.affirmative=>'success',
    PQActionStyle.secondary=>'neutral',
    PQActionStyle.destructive=>'danger',
    PQActionStyle.gold=>'gold',
  };
  String get _state=>(_busy||widget.loading)?'loading':_disabled?'disabled':_pressed?'pressed':_focused?'focused':'normal';
  Future<void> _run() async {
    if(_disabled)return;
    setState(()=>_busy=true);
    try {await widget.onPressed!();}
    catch(error,stack) {
      FlutterError.reportError(FlutterErrorDetails(
        exception:error,stack:stack,library:'PuzzleQuest component library',
        context:ErrorDescription('running the action ${widget.label}')));
      if (mounted) {
        final arabic = Localizations.localeOf(context).languageCode == 'ar';
        await showPuzzleMessage(context, arabic
          ? 'تعذّر إتمام العملية. حاول مرة تانية.'
          : 'Couldn’t complete the action. Please try again.', warning: true);
      }
    } finally {if(mounted)setState(()=>_busy=false);}
  }
  @override Widget build(BuildContext context){
    final darkLabel=widget.style==PQActionStyle.affirmative||widget.style==PQActionStyle.gold;
    final foreground=darkLabel?PQColors.background:PQColors.white;
    return Semantics(button:true,enabled:!_disabled,
      label:widget.semanticLabel??widget.label,
      child:ConstrainedBox(constraints:const BoxConstraints(minHeight:56,minWidth:110),
        child:FocusableActionDetector(
          enabled:!_disabled,
          onShowFocusHighlight:(v)=>setState(()=>_focused=v),
          child:Material(color:Colors.transparent,
            child:InkWell(onTap:_disabled?null:_run,
              onHighlightChanged:(v)=>setState(()=>_pressed=v),
              borderRadius:BorderRadius.circular(PQRadii.card),
              child:Container(
                alignment:Alignment.center,
                padding:const EdgeInsets.symmetric(horizontal:14,vertical:12),
                constraints:const BoxConstraints(minHeight:56),
                decoration:BoxDecoration(image:DecorationImage(
                  // These 600x156 PNGs are authored at 3x. Use logical-pixel
                  // slice coordinates so the fixed 56dp CTA height still
                  // contains both rounded caps on Android and iOS.
                  image:ExactAssetImage('assets/ui/buttons/${_family}_$_state.png',scale:3),
                  fit:BoxFit.fill,centerSlice:const Rect.fromLTRB(35,14,165,38))),
                child:(_busy||widget.loading)
                  ? SizedBox.square(dimension:22,child:CircularProgressIndicator(
                      strokeWidth:2.3,color:foreground,
                      semanticsLabel:'Loading'))
                  :Row(mainAxisSize:MainAxisSize.min,
                    mainAxisAlignment:MainAxisAlignment.center,
                    children:[if(widget.iconAsset!=null)...[
                      Image.asset(widget.iconAsset!,width:28,height:28,
                        fit:BoxFit.contain,excludeFromSemantics:true),
                      const SizedBox(width:8)] else if(widget.icon!=null)...[
                      Icon(widget.icon,size:19,color:foreground),
                      const SizedBox(width:6)],
                      Flexible(child:Text(widget.label,
                        textAlign:TextAlign.center,
                        style:TextStyle(color:foreground,fontWeight:FontWeight.w700))),
                    ]),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class PQIconAction extends StatelessWidget {
  const PQIconAction({super.key,required this.icon,required this.tooltip,this.onPressed});
  final IconData icon;final String tooltip;final VoidCallback? onPressed;
  @override Widget build(BuildContext context)=>IconButton(
    constraints:const BoxConstraints(minWidth:PQSpace.minTouch,minHeight:PQSpace.minTouch),
    tooltip:tooltip,icon:Icon(icon),onPressed:onPressed);
}

class PQHUDCurrency extends StatelessWidget {
  const PQHUDCurrency({super.key,required this.label,required this.amount,
    this.state=PQCurrencyState.settled,this.icon=Icons.monetization_on_outlined});
  final String label;final int? amount;final PQCurrencyState state;final IconData icon;
  @override Widget build(BuildContext context){
    final isSettled=state==PQCurrencyState.settled && amount!=null;
    return Semantics(label:'$label: ${isSettled?amount:'pending'}',
      child:Container(padding:const EdgeInsets.symmetric(horizontal:9,vertical:7),
        decoration:BoxDecoration(color:PQColors.surface,
          borderRadius:BorderRadius.circular(PQRadii.input),
          border:Border.all(color:state==PQCurrencyState.insufficient?PQColors.danger:PQColors.gold.withValues(alpha:.25))),
        child:Row(mainAxisSize:MainAxisSize.min,children:[
          if(icon==Icons.monetization_on_outlined || icon==Icons.lightbulb_outline)
            Image.asset('assets/design/art/rewards/${icon==Icons.lightbulb_outline?'hint_bulb':'coins_stack'}.png',
              width:20,height:20,fit:BoxFit.contain,excludeFromSemantics:true)
          else Icon(icon,size:16,color:PQColors.gold),
          const SizedBox(width:4),
          Text(isSettled?'$amount':'—',style:const TextStyle(fontWeight:FontWeight.w700)),
        ])),
    );
  }
}

class PQHUDTimer extends StatelessWidget {
  const PQHUDTimer({super.key,required this.remaining,required this.state,
    required this.label});
  final Duration remaining;final PQTimerState state;final String label;
  @override Widget build(BuildContext context){
    final millis=remaining.inMilliseconds.clamp(0,999999999);
    final time='${(millis~/60000).toString().padLeft(2,'0')}:${((millis~/1000)%60).toString().padLeft(2,'0')}';
    final urgent=millis<30000 || state==PQTimerState.expired;
    return Semantics(liveRegion:urgent,label:'$label: $time',
      child:Row(mainAxisSize:MainAxisSize.min,children:[
        Icon(state==PQTimerState.running?Icons.timer_outlined:Icons.pause_circle_outline,
          size:20,color:urgent?PQColors.danger:PQColors.gold),
        const SizedBox(width:4),
        Text(time,style:Theme.of(context).textTheme.titleMedium?.copyWith(
          fontWeight:FontWeight.bold,color:urgent?PQColors.danger:PQColors.gold)),
      ]));
  }
}

/// The result page must explicitly pass the backend-confirmed value.
class PQStarRating extends StatelessWidget {
  const PQStarRating({super.key,required this.stars,required this.confirmed,
    this.label='Stars'});
  final int stars;final bool confirmed;final String label;
  @override Widget build(BuildContext context){
    final count=stars.clamp(0,3);
    return Semantics(label:confirmed?'$label: $count of 3':'$label pending server confirmation',
      child:Row(mainAxisSize:MainAxisSize.min,children:List.generate(3,(index)=>Icon(
        confirmed&&index<count?Icons.star_rounded:Icons.star_border_rounded,
        size:30,color:confirmed?PQColors.gold:PQColors.muted))));
  }
}

class PQLevelTile extends StatelessWidget {
  const PQLevelTile({super.key,required this.title,required this.subtitle,
    required this.state,required this.onPlay,this.leading});
  final String title,subtitle;final PQLevelState state;
  final VoidCallback? onPlay;final Widget? leading;
  @override Widget build(BuildContext context){
    final allowed=state!=PQLevelState.locked && onPlay!=null;
    return Semantics(enabled:allowed,button:allowed,
      child:ListTile(contentPadding:const EdgeInsets.all(8),
        leading:leading??Icon(allowed?Icons.extension:Icons.lock,color:PQColors.gold),
        title:Text(title),subtitle:Text(subtitle),
        trailing:Icon(state==PQLevelState.perfect?Icons.stars:
          allowed?Icons.play_circle:Icons.lock_outline,color:PQColors.gold),
        onTap:allowed?onPlay:null));
  }
}
class PQWorldCard extends StatelessWidget {
  const PQWorldCard({super.key,required this.title,required this.subtitle,
    required this.published,this.onSelect});
  final String title,subtitle;final bool published;final VoidCallback? onSelect;
  @override Widget build(BuildContext context)=>ListTile(
    leading:Icon(published?Icons.park:Icons.lock_outline,color:PQColors.gold,size:32),
    title:Text(title),subtitle:Text(subtitle),
    trailing:Icon(published?Icons.chevron_right:Icons.lock,color:PQColors.gold),
    onTap:published?onSelect:null);
}

class PQPuzzlePieceView extends StatelessWidget {
  const PQPuzzlePieceView({super.key,required this.image,
    required this.label,required this.state,this.onSelect,this.reduceMotion=false,this.selected=false});
  final Uint8List image;final String label;final PQPieceState state;
  final VoidCallback? onSelect;final bool reduceMotion,selected;
  @override Widget build(BuildContext context)=>Semantics(button:onSelect!=null,label:label,
    child:AnimatedContainer(duration:PQMotion.resolve(PQMotion.snap,reduceMotion:reduceMotion),
      decoration:BoxDecoration(borderRadius:BorderRadius.circular(PQRadii.small),
        border:Border.all(width:selected||state==PQPieceState.nearSlot||state==PQPieceState.wrong?2:0,
          color:state==PQPieceState.wrong?PQColors.danger:PQColors.gold),
        boxShadow:state==PQPieceState.dragging?[BoxShadow(color:PQColors.background.withValues(alpha:.55),blurRadius:12)]:[]),
      child:InkWell(onTap:onSelect,child:Image.memory(image,fit:BoxFit.contain))));
}

class PQBoardStatusBanner extends StatelessWidget {
  const PQBoardStatusBanner({super.key,required this.state,required this.label});
  final PQBoardState state;final String label;
  @override Widget build(BuildContext context)=>Semantics(liveRegion:true,
    child:Row(mainAxisSize:MainAxisSize.min,children:[
      if(state==PQBoardState.loading)...[const SizedBox.square(dimension:16,
        child:CircularProgressIndicator(strokeWidth:2)),const SizedBox(width:6)],
      Text(label),
    ]));
}

class PQWalletPurchase extends StatelessWidget {
  const PQWalletPurchase({super.key,required this.title,required this.price,
    required this.availableCoins,required this.state,required this.onConfirm});
  final String title;final int price,availableCoins;final PQPurchaseState state;
  final FutureOr<void> Function()? onConfirm;
  @override Widget build(BuildContext context){
    final ar=Localizations.localeOf(context).languageCode=='ar';
    return Column(crossAxisAlignment:CrossAxisAlignment.stretch,
    children:[Text('$title • $price',style:Theme.of(context).textTheme.titleMedium),
      PQCTA(label:state==PQPurchaseState.success?(ar?'تم التأكيد':'Confirmed'):
        state==PQPurchaseState.declined?(ar?'مرفوض':'Declined'):
        availableCoins<price?(ar?'الرصيد غير كافٍ':'Insufficient coins'):
        (ar?'تأكيد الشراء':'Confirm purchase'),
        loading:state==PQPurchaseState.checking,
        onPressed:availableCoins<price||state==PQPurchaseState.success||state==PQPurchaseState.declined?null:onConfirm),
    ]);
  }
}

class PQRewardDialog extends StatelessWidget {
  const PQRewardDialog({super.key,required this.title,required this.state,
    required this.onClaim});
  final String title;final PQRewardState state;
  final FutureOr<void> Function()? onClaim;
  @override Widget build(BuildContext context)=>Column(mainAxisSize:MainAxisSize.min,children:[
    Text(title,style:Theme.of(context).textTheme.titleLarge),
    PQCTA(label:state==PQRewardState.claimed?
      (Localizations.localeOf(context).languageCode=='ar'?'تم الاستلام':'Claimed'):
      (Localizations.localeOf(context).languageCode=='ar'?'استلام':'Claim'),
      loading:state==PQRewardState.loading,
      iconAsset:'assets/design/art/rewards/coins_stack.png',
      onPressed:state==PQRewardState.collectible?onClaim:null,
      style:PQActionStyle.affirmative),
  ]);
}

class PQAdChoice extends StatelessWidget {
  const PQAdChoice({super.key,required this.title,required this.state,
    required this.onWatch});
  final String title;final PQAdState state;
  final FutureOr<void> Function()? onWatch;
  @override Widget build(BuildContext context)=>PQCTA(label:title,
    iconAsset:'assets/design/art/rewards/coins_stack.png',
    loading:state==PQAdState.loading,
    onPressed:state==PQAdState.eligible?onWatch:null,
    style:PQActionStyle.secondary);
}

class PQBuildingCard extends StatelessWidget {
  const PQBuildingCard({super.key,required this.title,required this.stage,
    required this.state,required this.onUpgrade});
  final String title;final int stage;final PQBuildingState state;
  final FutureOr<void> Function()? onUpgrade;
  @override Widget build(BuildContext context){
    assert(stage>=0&&stage<=4,'Building stages must stay within L0–L4');
    return Column(children:[ListTile(leading:const Icon(Icons.cottage,color:PQColors.gold),
      title:Text(title),subtitle:Text('L$stage / L4')),
      PQCTA(label:stage==4?'Restored': 'Upgrade',
        loading:state==PQBuildingState.upgrading,
        onPressed:state==PQBuildingState.ready?onUpgrade:null),
    ]);
  }
}

class PQMissionRow extends StatelessWidget {
  const PQMissionRow({super.key,required this.title,required this.progress,
    required this.goal,required this.daily,required this.state,this.onClaim});
  final String title;final int progress,goal;final bool daily;
  final PQMissionState state;final FutureOr<void> Function()? onClaim;
  @override Widget build(BuildContext context)=>ListTile(
    title:Text(title),subtitle:Text('${daily?(Localizations.localeOf(context).languageCode=='ar'?'يومية':'Daily'):(Localizations.localeOf(context).languageCode=='ar'?'أسبوعية':'Weekly')} • $progress / $goal'),
    trailing:state==PQMissionState.claimable?
      SizedBox(width:105,child:PQCTA(label:Localizations.localeOf(context).languageCode=='ar'?'استلام':'Claim',onPressed:onClaim)):
      Text(state==PQMissionState.claimed?(Localizations.localeOf(context).languageCode=='ar'?'تم الاستلام':'Claimed'):'${(goal==0?0:(100*progress/goal)).clamp(0,100).round()}%'));
}

class PQTrophyBadge extends StatelessWidget {
  const PQTrophyBadge({super.key,required this.title,required this.criterion,
    required this.earned});
  final String title,criterion;final bool earned;
  @override Widget build(BuildContext context){
    final ar=Localizations.localeOf(context).languageCode=='ar';
    const descriptionsEn={
      'first_steps':'Complete your first stage',
      'green_valley_explorer':'Complete the five Green Valley stages',
      'perfect_solver':'Finish a stage with three stars',
      'star_collector':'Collect ten stars',
      'puzzle_master':'Earn three stars on three different stages',
    };
    const descriptionsAr={
      'first_steps':'أكمل المرحلة الأولى',
      'green_valley_explorer':'أكمل مراحل الوادي الأخضر الخمس',
      'perfect_solver':'أكمل مرحلة بثلاث نجوم',
      'star_collector':'اجمع عشر نجوم',
      'puzzle_master':'احصل على ثلاث نجوم في ثلاث مراحل مختلفة',
    };
    const titlesAr={
      'first_steps':'الخطوات الأولى',
      'green_valley_explorer':'مستكشف الوادي الأخضر',
      'perfect_solver':'الحل المثالي',
      'star_collector':'جامع النجوم',
      'puzzle_master':'خبير البازل',
    };
    final description=(ar?descriptionsAr:descriptionsEn)[criterion]??criterion;
    final displayTitle=ar?(titlesAr[criterion]??title):title;
    return Semantics(label:'$displayTitle: $description',
      child:ListTile(leading:Icon(Icons.emoji_events,
        color:earned?PQColors.gold:PQColors.muted,size:32),
        title:Text(displayTitle),subtitle:Text(description),
        trailing:Icon(earned?Icons.check_circle:Icons.lock_outline)));
  }
}

class PQLanguageSwitcher extends StatelessWidget {
  const PQLanguageSwitcher({super.key,required this.arabic,required this.onChanged});
  final bool arabic;final ValueChanged<bool> onChanged;
  @override Widget build(BuildContext context)=>SwitchListTile(
    title:Text(arabic?'اللغة العربية':'Arabic language'),
    value:arabic,onChanged:onChanged);
}

class PQNotificationTile extends StatelessWidget {
  const PQNotificationTile({super.key,required this.title,required this.body,
    required this.state,this.onOpen});
  final String title,body;final PQNotificationState state;
  final VoidCallback? onOpen;
  @override Widget build(BuildContext context)=>ListTile(
    minTileHeight:81,leading:Icon(state==PQNotificationState.unread?
      Icons.markunread:Icons.notifications_outlined,color:PQColors.gold),
    title:Text(title,maxLines:1,overflow:TextOverflow.ellipsis),
    subtitle:Text(body,maxLines:2,overflow:TextOverflow.ellipsis),
    enabled:state!=PQNotificationState.expired,onTap:state==PQNotificationState.expired?null:onOpen);
}

class PQInlineStatus extends StatelessWidget {
  const PQInlineStatus({super.key,required this.state,required this.message,this.onRetry});
  final PQInlineState state;final String message;final VoidCallback? onRetry;
  @override Widget build(BuildContext context)=>Semantics(liveRegion:true,child:Column(
    mainAxisSize:MainAxisSize.min,children:[
      if(state==PQInlineState.loading)const CircularProgressIndicator(),
      Text(message,textAlign:TextAlign.center),
      if(state!=PQInlineState.loading && onRetry!=null)
        TextButton(onPressed:onRetry,child:Text(Localizations.localeOf(context).languageCode=='ar'?'إعادة المحاولة':'Retry')),
    ]));
}

class PQConfirmationSheet extends StatelessWidget {
  const PQConfirmationSheet({super.key,required this.title,required this.message,
    required this.onConfirm,required this.onCancel,this.busy=false,this.destructive=false});
  final String title,message;final FutureOr<void> Function()? onConfirm;
  final VoidCallback onCancel;final bool busy,destructive;
  @override Widget build(BuildContext context)=>SafeArea(child:ConstrainedBox(
    constraints:const BoxConstraints(maxWidth:342),child:Padding(
      padding:const EdgeInsets.all(PQSpace.x5),child:Column(
        mainAxisSize:MainAxisSize.min,children:[
          Text(title,style:Theme.of(context).textTheme.titleLarge),
          const SizedBox(height:PQSpace.x4),Text(message),
          const SizedBox(height:PQSpace.x4),
          PQCTA(label:Localizations.localeOf(context).languageCode=='ar'?'تأكيد':'Confirm',loading:busy,
            style:destructive?PQActionStyle.destructive:PQActionStyle.primary,
            onPressed:busy?null:onConfirm),
          const SizedBox(height:PQSpace.x2),
          PQCTA(label:Localizations.localeOf(context).languageCode=='ar'?'إلغاء':'Cancel',onPressed:busy?null:onCancel,style:PQActionStyle.secondary),
        ]))));
}
