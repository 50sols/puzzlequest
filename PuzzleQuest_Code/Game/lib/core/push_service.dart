import 'dart:async';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'session.dart';

/// FCM/APNs registration is opt-in; Inbox is still available without Push.
/// Build flag prevents accidental activation before Apple APNs and FCM IAM
/// have been configured and tested on real devices.
class PushService {
  PushService(this.session);
  final PuzzleSession session;
  static const enabledInBuild = bool.fromEnvironment('PUSH_CONFIGURED',defaultValue:false);
  StreamSubscription<String>? _tokenSubscription;
  Future<bool> configure({required bool userConsent}) async {
    if(!userConsent || !enabledInBuild || !session.authenticated)return false;
    await Firebase.initializeApp();
    final messaging=FirebaseMessaging.instance;
    await messaging.setAutoInitEnabled(true);
    final settings=await messaging.requestPermission(alert:true,badge:true,sound:true,provisional:false);
    if(settings.authorizationStatus!=AuthorizationStatus.authorized)return false;
    final token=await messaging.getToken();
    if(token!=null)await _register(token);
    _tokenSubscription?.cancel();
    _tokenSubscription=messaging.onTokenRefresh.listen((token){
      unawaited(_register(token).catchError((Object _){}));
    });
    return true;
  }
  Future<void> _register(String token) async {
    await session.api.post('push/devices',{
      'token':token,
      'platform':defaultTargetPlatform==TargetPlatform.iOS?'ios':'android',
      'permission':true,
    });
  }
  Future<void> disable() async {
    _tokenSubscription?.cancel();
    if(!enabledInBuild)return;
    try{
      final messaging=FirebaseMessaging.instance;
      await messaging.setAutoInitEnabled(false);
      await messaging.deleteToken();
    }catch(_){ /* Server consent remains OFF independently. */ }
  }
  void dispose(){_tokenSubscription?.cancel();}
}
