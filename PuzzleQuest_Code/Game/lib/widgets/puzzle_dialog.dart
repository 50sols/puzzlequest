import 'dart:ui' as ui;
import 'package:flutter/material.dart';

enum PuzzleDialogArt { warning, offline, ad_unavailable, server }

class PuzzleDialog extends StatelessWidget {
  const PuzzleDialog({super.key,this.title,this.content,this.actions,this.icon,
    this.constraints,this.scrollable=true,this.actionsAlignment,
    this.art=PuzzleDialogArt.warning,this.showHeader=true});
  final Widget? title,content,icon;
  final List<Widget>? actions;
  final BoxConstraints? constraints;
  final bool scrollable,showHeader;
  final MainAxisAlignment? actionsAlignment;
  final PuzzleDialogArt art;

  @override
  Widget build(BuildContext context) {
    final available=MediaQuery.sizeOf(context).height-
      MediaQuery.viewInsetsOf(context).bottom-64;
    return BackdropFilter(filter:ui.ImageFilter.blur(sigmaX:4,sigmaY:4),
      child:Dialog(backgroundColor:Colors.transparent,surfaceTintColor:Colors.transparent,
        elevation:0,insetPadding:const EdgeInsets.symmetric(horizontal:36,vertical:24),
        constraints:const BoxConstraints(minWidth:0,maxWidth:310),
        child:ConstrainedBox(constraints:BoxConstraints(maxWidth:310,
          maxHeight:available.clamp(120,double.infinity)),
          child:DecoratedBox(decoration:const BoxDecoration(image:DecorationImage(
            image:AssetImage('assets/ui/popups/panel.png'),fit:BoxFit.fill)),
            child:SingleChildScrollView(padding:const EdgeInsets.fromLTRB(24,52,24,48),
              child:Column(mainAxisSize:MainAxisSize.min,crossAxisAlignment:CrossAxisAlignment.stretch,
                children:[
                  if(showHeader)...[
                    Image.asset('assets/ui/popups/${art.name}.png',height:100,
                      fit:BoxFit.contain,excludeFromSemantics:true),
                    const SizedBox(height:12),
                  ],
                  if(title!=null)...[
                    Container(alignment:Alignment.center,
                      padding:const EdgeInsets.fromLTRB(22,24,22,20),
                      decoration:const BoxDecoration(image:DecorationImage(
                        image:AssetImage('assets/ui/popups/heading.png'),fit:BoxFit.fill)),
                      child:DefaultTextStyle.merge(textAlign:TextAlign.center,
                        style:const TextStyle(fontSize:21,fontWeight:FontWeight.w700,color:Colors.white),child:title!)),
                    const SizedBox(height:12),
                  ],
                  if(content!=null)DefaultTextStyle.merge(textAlign:TextAlign.center,
                    style:const TextStyle(fontSize:16,color:Color(0xFFF7E8FF)),child:content!),
                  if(actions!=null)...[
                    const SizedBox(height:20),
                    for(final (index,action) in actions!.reversed.indexed)
                      Padding(padding:const EdgeInsets.only(top:8),
                        child:_action(action,index==0)),
                  ],
                ])),
          )),
      ));
  }

  Widget _action(Widget action,bool primary) {
    if(action is! ButtonStyleButton || action.child==null) return action;
    return PuzzlePopupButton(onPressed:action.onPressed,primary:primary,child:action.child!);
  }
}

class PuzzlePopupButton extends StatelessWidget {
  const PuzzlePopupButton({super.key,required this.child,this.onPressed,this.primary=true});
  final Widget child;
  final VoidCallback? onPressed;
  final bool primary;
  @override
  Widget build(BuildContext context)=>Opacity(opacity:onPressed == null ? .5 : 1,
    child:Material(color:Colors.transparent,child:InkWell(onTap:onPressed,
      borderRadius:BorderRadius.circular(28),child:Container(
        constraints:const BoxConstraints(minHeight:52),alignment:Alignment.center,
        padding:const EdgeInsets.symmetric(horizontal:20,vertical:14),
        decoration:BoxDecoration(image:DecorationImage(
          image:AssetImage('assets/ui/popups/${primary?'primary':'secondary'}.png'),fit:BoxFit.fill)),
        child:DefaultTextStyle.merge(style:TextStyle(fontSize:18,fontWeight:FontWeight.w700,
          color:primary?const Color(0xFF4B125E):Colors.white),child:child),
      ))));
}

Future<T?> showPuzzleSheet<T>({required BuildContext context,
  required WidgetBuilder builder,bool isScrollControlled=false,Color? backgroundColor})=>
  showDialog<T>(context:context,builder:(dialog)=>PuzzleDialog(showHeader:false,content:builder(dialog)));
