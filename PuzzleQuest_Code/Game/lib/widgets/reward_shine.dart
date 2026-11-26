import 'package:flutter/material.dart';

/// Shine is masked to the artwork/text alpha, including transparent PNG edges.
class RewardShine extends StatefulWidget {
  const RewardShine({super.key, required this.child, required this.enabled,
    this.gold = false});
  final Widget child;
  final bool enabled, gold;
  @override
  State<RewardShine> createState() => _RewardShineState();
}

class _RewardShineState extends State<RewardShine> with SingleTickerProviderStateMixin {
  late final AnimationController _shine = AnimationController(vsync:this,
    duration:const Duration(milliseconds:3800));
  @override
  void initState() { super.initState(); if(widget.enabled) _shine.repeat(); }
  @override
  void didUpdateWidget(covariant RewardShine oldWidget) {
    super.didUpdateWidget(oldWidget);
    if(widget.enabled == oldWidget.enabled) return;
    if(widget.enabled) { _shine.repeat(); } else { _shine.stop(); }
  }
  @override
  void dispose() { _shine.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    if(!widget.enabled) return widget.child;
    return RepaintBoundary(child:AnimatedBuilder(animation:_shine,
      child:widget.child,builder:(context,child)=>ShaderMask(
        blendMode:widget.gold?BlendMode.srcIn:BlendMode.srcATop,
        shaderCallback:(bounds) {
          final x = (_shine.value / .45).clamp(0.0,1.0) * 4 - 2;
          return LinearGradient(begin:Alignment(x-1,-.4),end:Alignment(x+1,.4),
            colors:widget.gold
              ? const [Color(0xFFFFBF31),Color(0xFFFFBF31),Color(0xFFFFFFD8),Color(0xFFFFBF31),Color(0xFFFFBF31)]
              : const [Colors.transparent,Colors.transparent,Color(0xB3FFFFFF),Colors.transparent,Colors.transparent],
            stops:const [0,.38,.5,.62,1]).createShader(bounds);
        },child:child)));
  }
}
