import 'dart:typed_data';
import 'package:flutter/material.dart';
import '../core/content.dart';
import '../core/models.dart';

class VerifiedLevelImage extends StatefulWidget {
  const VerifiedLevelImage({super.key,required this.level,this.width,this.height,this.fit=BoxFit.cover});
  final LevelSpec level;final double? width,height;
  final BoxFit fit;
  @override State<VerifiedLevelImage> createState()=>_VerifiedLevelImageState();
}
class _VerifiedLevelImageState extends State<VerifiedLevelImage> {
  final _store=ContentStore();
  late Future<Uint8List> _future;
  @override void initState(){super.initState();_future=_store.master(widget.level);}
  @override void didUpdateWidget(VerifiedLevelImage old){super.didUpdateWidget(old);
    if(old.level.id!=widget.level.id||old.level.revision!=widget.level.revision){
      _future=_store.master(widget.level);
    }
  }
  @override void dispose(){_store.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>FutureBuilder<Uint8List>(future:_future,builder:(ctx,snapshot){
    if(!snapshot.hasData){return SizedBox(width:widget.width,height:widget.height,
      child:snapshot.hasError?IconButton(
        tooltip:Localizations.localeOf(context).languageCode=='ar'?'إعادة تحميل الصورة':'Retry image',
        onPressed:()=>setState(()=>_future=_store.master(widget.level)),
        icon:const Icon(Icons.refresh,color:Colors.amber)):
        const Icon(Icons.extension,color:Colors.amber));}
    return Image.memory(snapshot.data!,width:widget.width,height:widget.height,fit:widget.fit);
  });
}
