import 'package:flutter/material.dart';
import '../core/theme.dart';
import 'component_library.dart';

/// DOC 03 development-only preview. NOT registered in player navigation.
/// All amounts and state labels shown here are visual fixtures, never wallet
/// or game data; this page cannot contact the API or grant any entitlement.
class PQComponentPreview extends StatelessWidget {
  const PQComponentPreview({super.key});
  @override Widget build(BuildContext context){
    final ar=Localizations.localeOf(context).languageCode=='ar';
    return Scaffold(appBar:AppBar(title:Text(ar?'مراجعة مكتبة المكونات':'Component Preview')),
      body:SafeArea(child:ListView(padding:const EdgeInsets.all(PQSpace.x4),children:[
        Text(ar?'معاينة تطوير فقط — لا بيانات حية':'DEVELOPMENT PREVIEW — NO LIVE DATA',
          style:const TextStyle(color:PQColors.gold)),
        const SizedBox(height:12),
        for(final family in const ['primary','success','neutral','danger'])...[
          Text('Approved button exports: $family'),
          SizedBox(height:65,child:ListView(scrollDirection:Axis.horizontal,children:[
            for(final state in const ['normal','pressed','focused','disabled','loading'])
              SizedBox(width:120,child:Column(children:[
                Text(state,style:const TextStyle(fontSize:11)),
                Expanded(child:Image.asset('assets/ui/buttons/${family}_$state.png',fit:BoxFit.contain)),
              ])),
          ])),
          const Divider(),
        ],
        PQCTA(label:'Enabled / متاح',onPressed:()=>{}),
        const SizedBox(height:8),
        const PQCTA(label:'Disabled / معطل',onPressed:null,style:PQActionStyle.secondary),
        const SizedBox(height:8),
        const PQCTA(label:'Loading / تحميل',onPressed:null,loading:true),
        const SizedBox(height:12),
        const Wrap(spacing:8,runSpacing:8,children:[
          PQHUDCurrency(label:'Pending coins',amount:null,state:PQCurrencyState.pending),
          PQHUDCurrency(label:'Confirmed coins',amount:300),
          PQHUDCurrency(label:'Insufficient coins',amount:0,state:PQCurrencyState.insufficient),
          PQHUDTimer(remaining:Duration(minutes:2,seconds:30),state:PQTimerState.running,label:'Time'),
          PQHUDTimer(remaining:Duration.zero,state:PQTimerState.expired,label:'Expired'),
          PQStarRating(stars:3,confirmed:false),
          PQStarRating(stars:2,confirmed:true),
        ]),
        const Divider(),
        const PQLevelTile(title:'Level 1-1',subtitle:'Locked visual state',
          state:PQLevelState.locked,onPlay:null),
        const PQWorldCard(title:'Snow Land',subtitle:'Not published',published:false),
        const Divider(),
        const PQWalletPurchase(title:'Hint',price:100,availableCoins:0,
          state:PQPurchaseState.confirm,onConfirm:null),
        const PQRewardDialog(title:'Daily Reward',state:PQRewardState.claimed,onClaim:null),
        const PQAdChoice(title:'Rewarded Ad — not available',state:PQAdState.unavailable,onWatch:null),
        const PQBuildingCard(title:'Cottage',stage:0,state:PQBuildingState.ruined,onUpgrade:null),
        const PQMissionRow(title:'Daily Player',progress:0,goal:1,daily:true,state:PQMissionState.open),
        const PQTrophyBadge(title:'First Steps',criterion:'Finish a stage',earned:false),
        const PQNotificationTile(title:'Notification',body:'Read only in preview',state:PQNotificationState.read),
        const PQInlineStatus(state:PQInlineState.empty,message:'No data in preview'),
        const Divider(),
        PQConfirmationSheet(title:'Developer preview',message:'No real action',
          onConfirm:null,onCancel:_noOp),
      ])));
  }
  static void _noOp() {}
}
