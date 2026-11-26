import 'dart:async';
import 'package:flutter/material.dart';
import '../core/session.dart';
import '../core/theme.dart';
import 'component_library.dart';

class PQBackdrop extends StatelessWidget {
  const PQBackdrop({super.key,required this.child,this.bright=false});
  final Widget child;
  final bool bright;
  @override Widget build(BuildContext context)=>Container(
    decoration:const BoxDecoration(image:DecorationImage(
      image:AssetImage('assets/images/app_background.png'),fit:BoxFit.cover,
      colorFilter:ColorFilter.mode(Color(0x59000000),BlendMode.darken))),
    child:child,
  );
}

class PQCard extends StatelessWidget {
  const PQCard({super.key,required this.child,this.padding=const EdgeInsets.all(16)});
  final Widget child; final EdgeInsets padding;
  @override Widget build(BuildContext context)=>Container(
    margin:const EdgeInsets.symmetric(vertical:6),padding:padding,
    decoration:BoxDecoration(gradient:const LinearGradient(colors:[PQColors.panel,PQColors.surface]),
      borderRadius:BorderRadius.circular(20),border:Border.all(color:PQColors.gold.withValues(alpha:0.22))),
    child:child,
  );
}
class PQTopBar extends StatelessWidget {
  const PQTopBar({super.key,required this.session,required this.title});
  final PuzzleSession session;final String title;
  @override Widget build(BuildContext context)=>Row(children:[
    Expanded(child:Text(title,maxLines:2,
      style:Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight:FontWeight.w700))),
    PQHUDCurrency(label:session.tr('العملات','Coins'),
      amount:session.authenticated?session.coins:null,
      state:session.authenticated?PQCurrencyState.settled:PQCurrencyState.pending),
    const SizedBox(width:6),
    PQHUDCurrency(label:session.tr('النجوم','Stars'),
      icon:Icons.star_rounded,amount:session.authenticated?session.stars:null,
      state:session.authenticated?PQCurrencyState.settled:PQCurrencyState.pending),
  ]);
}
class PQAction extends StatelessWidget {
  const PQAction({super.key,required this.label,required this.onPressed,this.icon,
    this.outlined=false,this.loading=false,this.style=PQActionStyle.affirmative,this.iconAsset});
  final String label;
  final FutureOr<void> Function()? onPressed;
  final IconData? icon;
  final bool outlined,loading;
  final PQActionStyle style;
  final String? iconAsset;
  @override Widget build(BuildContext context)=>PQCTA(
    label:label,onPressed:onPressed,icon:icon,iconAsset:iconAsset,loading:loading,
    style:outlined?PQActionStyle.secondary:style);
}
class PQSectionTitle extends StatelessWidget {
  const PQSectionTitle({super.key,required this.text});final String text;
  @override Widget build(BuildContext context)=>Padding(padding:const EdgeInsets.symmetric(vertical:12),
    child:Text(text,style:Theme.of(context).textTheme.titleMedium?.copyWith(color:PQColors.gold,fontWeight:FontWeight.bold)));
}
class PQEmpty extends StatelessWidget {
  const PQEmpty({super.key,required this.text,this.retry});
  final String text;final VoidCallback? retry;
  @override Widget build(BuildContext context)=>Center(child:Padding(padding:const EdgeInsets.all(24),
    child:Column(mainAxisSize:MainAxisSize.min,children:[
      const Icon(Icons.hourglass_empty,size:52,color:PQColors.gold),const SizedBox(height:12),
      Text(text,textAlign:TextAlign.center),if(retry!=null)...[
        const SizedBox(height:12),PQAction(label:'Retry / إعادة المحاولة',onPressed:retry),
      ],
    ])));
}
