import 'package:flutter/material.dart';

class GameArtButton extends StatelessWidget {
  const GameArtButton({super.key, required this.asset, required this.label,
    required this.crop, this.onPressed, this.badge = 0,this.sourceAspectRatio});
  final String asset, label;
  final Rect crop;
  final VoidCallback? onPressed;
  final int badge;
  final double? sourceAspectRatio;

  @override
  Widget build(BuildContext context) => Semantics(button:true,
    enabled:onPressed!=null,label:label,child:Tooltip(message:label,
      child:Material(color:Colors.transparent,child:InkWell(
        onTap:onPressed,borderRadius:BorderRadius.circular(16),
        child:Opacity(opacity:onPressed == null ? .45 : 1,child:SizedBox(height:72,
          child:Stack(fit:StackFit.expand,children:[
            ExcludeSemantics(child:Center(child:AspectRatio(
              aspectRatio:(sourceAspectRatio ?? (asset.contains('hint')?1.5:4/3))*crop.width/crop.height,
              child:ClipRect(child:LayoutBuilder(builder:(context,box)=>
              Stack(children:[Positioned(
                left:-crop.left*box.maxWidth/crop.width,
                top:-crop.top*box.maxHeight/crop.height,
                width:box.maxWidth/crop.width,height:box.maxHeight/crop.height,
                child:Image.asset(asset,fit:BoxFit.fill),
              )])))))),
            if(badge>0)PositionedDirectional(end:3,top:0,child:Container(
              padding:const EdgeInsets.symmetric(horizontal:6,vertical:2),
              decoration:BoxDecoration(color:const Color(0xFFD9233B),
                borderRadius:BorderRadius.circular(12)),
              child:Text('$badge',style:const TextStyle(fontSize:11,fontWeight:FontWeight.bold)),
            )),
          ]))),
      ))));
}
