import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzlequest_game/core/theme.dart';
import 'package:puzzlequest_game/widgets/component_library.dart';

Widget harness(Widget child,{bool arabic=false,double width=390})=>
  MaterialApp(theme:puzzleTheme(arabic),home:Directionality(
    textDirection:arabic?TextDirection.rtl:TextDirection.ltr,
    child:Scaffold(body:Center(child:SizedBox(width:width,child:child)))));

void main(){
  testWidgets('CTA artwork paints after decoding at minimum button size',(tester)async{
    for(final style in PQActionStyle.values){
      await tester.pumpWidget(harness(Column(mainAxisSize:MainAxisSize.min,
        crossAxisAlignment:CrossAxisAlignment.stretch,children:[PQCTA(
        label:'Play',style:style,onPressed:(){})]),width:110));
      final context=tester.element(find.byType(PQCTA));
      final decoration=tester.widgetList<Container>(find.descendant(
        of:find.byType(PQCTA),matching:find.byType(Container)))
        .map((container)=>container.decoration).whereType<BoxDecoration>()
        .firstWhere((decoration)=>decoration.image!=null);
      await tester.runAsync(()=>precacheImage(decoration.image!.image,context));
      await tester.pump();
      expect(tester.takeException(),isNull,reason:'$style artwork must paint');
      expect(tester.getSize(find.byType(PQCTA)).height,56);
    }
  });

  testWidgets('primary CTA runs one action and respects disabled state',(tester)async{
    var invocations=0;
    await tester.pumpWidget(harness(PQCTA(label:'Play',onPressed:()=>invocations++)));
    await tester.tap(find.text('Play'));await tester.pump();
    expect(invocations,1);
    await tester.pumpWidget(harness(const PQCTA(label:'Locked',onPressed:null)));
    await tester.tap(find.text('Locked'));await tester.pump();
    expect(invocations,1);
  });

  testWidgets('async CTA blocks duplicate submissions while waiting',(tester)async{
    final pending=Completer<void>();var submitted=0;
    await tester.pumpWidget(harness(PQCTA(label:'Claim',onPressed:(){
      submitted++;return pending.future;
    })));
    await tester.tap(find.text('Claim'));await tester.pump();
    await tester.tap(find.byType(PQCTA));await tester.pump();
    expect(submitted,1);
    pending.complete();await tester.pump();
  });

  testWidgets('server pending stars never show an earned star',(tester)async{
    await tester.pumpWidget(harness(const PQStarRating(stars:3,confirmed:false)));
    expect(find.byIcon(Icons.star_rounded),findsNothing);
    await tester.pumpWidget(harness(const PQStarRating(stars:2,confirmed:true)));
    expect(find.byIcon(Icons.star_rounded),findsNWidgets(2));
  });

  testWidgets('currency pending state is not shown as zero',(tester)async{
    await tester.pumpWidget(harness(const PQHUDCurrency(
      label:'Coins',amount:null,state:PQCurrencyState.pending)));
    expect(find.text('—'),findsOneWidget);
    expect(find.text('0'),findsNothing);
  });

  testWidgets('countdown renders remaining monotonic time',(tester)async{
    await tester.pumpWidget(harness(const PQHUDTimer(
      label:'Remaining',remaining:Duration(minutes:1,seconds:9),
      state:PQTimerState.running)));
    expect(find.text('01:09'),findsOneWidget);
  });

  testWidgets('locked level never invokes gameplay',(tester)async{
    var launched=false;
    await tester.pumpWidget(harness(PQLevelTile(title:'1-5',subtitle:'100 pieces',
      state:PQLevelState.locked,onPlay:()=>launched=true)));
    await tester.tap(find.text('1-5'));await tester.pump();
    expect(launched,false);
  });

  testWidgets('wallet purchase cannot bypass insufficient balance',(tester)async{
    var spent=false;
    await tester.pumpWidget(harness(PQWalletPurchase(title:'Hint',price:100,
      availableCoins:0,state:PQPurchaseState.confirm,onConfirm:()=>spent=true)));
    await tester.tap(find.text('Insufficient coins'));await tester.pump();
    expect(spent,false);
  });

  testWidgets('missions only allow claims when server says claimable',(tester)async{
    var claimed=false;
    await tester.pumpWidget(harness(PQMissionRow(title:'Puzzle Builder',
      progress:30,goal:30,daily:true,state:PQMissionState.claimed,
      onClaim:()=>claimed=true)));
    expect(find.text('Claimed'),findsOneWidget);expect(claimed,false);
    await tester.pumpWidget(harness(PQMissionRow(title:'Puzzle Builder',
      progress:30,goal:30,daily:true,state:PQMissionState.claimable,
      onClaim:()=>claimed=true)));
    await tester.tap(find.text('Claim'));await tester.pump();
    expect(claimed,true);
  });

  testWidgets('Arabic CTA and language preference reflow on phone',(tester)async{
    var english=false;
    await tester.pumpWidget(harness(Column(mainAxisSize:MainAxisSize.min,children:[
      const PQCTA(label:'استلام المكافأة اليومية',onPressed:null),
      PQLanguageSwitcher(arabic:true,onChanged:(arabic)=>english=!arabic),
    ]),arabic:true,width:320));
    await tester.tap(find.byType(SwitchListTile));await tester.pump();
    expect(english,true);
    expect(tester.takeException(),isNull);
  });

  testWidgets('rewarded ad unavailable state does not call native ad',(tester)async{
    var watched=false;
    await tester.pumpWidget(harness(PQAdChoice(title:'Rewarded preview',
      state:PQAdState.unavailable,onWatch:()=>watched=true)));
    await tester.tap(find.text('Rewarded preview'));await tester.pump();
    expect(watched,false);
  });
}
