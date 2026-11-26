import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'session.dart';
import 'models.dart';

/// Ads never grant resources locally. Only a signed Google SSV callback to
/// Laravel can change a wallet or add a preview entitlement.
class RewardedAdsService {
  RewardedAdsService(this.session);
  final PuzzleSession session;
  static const bool buildConfigured = bool.fromEnvironment('ADMOB_CONFIGURED',defaultValue:false);
  static const bool testAds = true;
  static bool get canPreviewTestAd => testAds && !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  static Future<void> previewTestAd() async {
    if (!canPreviewTestAd) throw StateError('Test ads require a mobile debug build');
    final adUnit = defaultTargetPlatform == TargetPlatform.android
        ? 'ca-app-pub-3940256099942544/5224354917'
        : 'ca-app-pub-3940256099942544/1712485313';
    await MobileAds.instance.initialize();
    final loaded = Completer<RewardedAd>();
    await RewardedAd.load(adUnitId: adUnit, request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          if (loaded.isCompleted) {
            unawaited(ad.dispose());
          } else {
            loaded.complete(ad);
          }
        },
        onAdFailedToLoad: (error) {
          if (!loaded.isCompleted) loaded.completeError(StateError(error.message));
        },
      ),
    );
    final ad = await loaded.future.timeout(const Duration(seconds: 30), onTimeout: () {
      final error = TimeoutException('Test ad did not load');
      // Complete the original future too, so a late ad gets disposed.
      loaded.completeError(error);
      throw error;
    });
    final closed = Completer<void>();
    ad.fullScreenContentCallback = FullScreenContentCallback<RewardedAd>(
      onAdDismissedFullScreenContent: (_) => closed.complete(),
      onAdFailedToShowFullScreenContent: (_, error) => closed.completeError(StateError(error.message)),
    );
    try {
      await ad.show(onUserEarnedReward: (_, _) {});
      await closed.future.timeout(const Duration(minutes: 3));
    } finally {
      await ad.dispose();
    }
  }

  Future<Map<String,dynamic>> showRewarded({required String attemptId,required String kind}) async {
    if (testAds) {
      await previewTestAd();
      return {'test_ad': true};
    }
    if (!buildConfigured) throw StateError('AdMob App IDs are not configured for this build');
    final request=await session.api.post('ads/requests',{'attempt_id':attemptId,'type':kind});
    final rewardId='${request['reward_request_id']}';
    final ssv=obj(request['ssv']);
    final unit='${request['ad_unit']}';
    if(rewardId=='null'||unit.isEmpty)throw StateError('Invalid ad configuration');
    await MobileAds.instance.initialize();
    final loaded=Completer<RewardedAd>();
    await RewardedAd.load(adUnitId:unit,request:const AdRequest(),
      rewardedAdLoadCallback:RewardedAdLoadCallback(
        onAdLoaded:loaded.complete,
        onAdFailedToLoad:(e)=>loaded.completeError(StateError('Ad unavailable: $e')),
      ));
    final ad=await loaded.future.timeout(const Duration(seconds:30));
    final finished=Completer<void>();
    try {
      await ad.setServerSideOptions(ServerSideVerificationOptions(
        userId:'${ssv['user_id']}', customData:'${ssv['custom_data']}',
      ));
      ad.fullScreenContentCallback=FullScreenContentCallback<RewardedAd>(
        onAdDismissedFullScreenContent:(_) {if(!finished.isCompleted)finished.complete();},
        onAdFailedToShowFullScreenContent:(_,error) {
          if(!finished.isCompleted)finished.completeError(StateError('$error'));
        },
      );
      await ad.show(onUserEarnedReward:(_, reward){
        // Google confirmation on device is NOT an SSV grant.
      });
      await finished.future.timeout(const Duration(minutes:3));
    } finally {await ad.dispose();}
    for(var i=0;i<12;i++){
      await Future<void>.delayed(const Duration(seconds:2));
      final status=await session.api.get('ads/requests/$rewardId');
      if(obj(status['request'])['state']=='granted') {
        await session.refreshPlayer();
        return status;
      }
    }
    throw StateError('Waiting for verified AdMob callback; no reward has been granted yet');
  }
}
