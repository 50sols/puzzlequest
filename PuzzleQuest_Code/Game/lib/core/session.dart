import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'api.dart';
import 'models.dart';
import 'push_service.dart';

class PuzzleSession extends ChangeNotifier {
  PuzzleSession({ApiClient? client}) : api = client ?? ApiClient();
  final ApiClient api;
  PushService? _pushService;
  final _secure = const FlutterSecureStorage();
  static const String tokenKey = 'puzzlequest.v1.token';
  bool ready = false, busy = false, offline = false, arabic = true;
  bool reduceMotion = false, soundEnabled = true, hapticsEnabled = true;
  String? status;
  Map<String,dynamic> player = {}, daily = {}, catalogData = {};
  List<LevelSpec> levels = const [];
  List<dynamic> worlds = const [];
  String? previousGuestToken;
  final Map<String, dynamic> _cache = {};

  int get coins => number(obj(player['wallet'])['coins']);
  int get hints => number(obj(player['wallet'])['hints']);
  int get shuffles => number(obj(player['wallet'])['shuffle_uses']);
  int get fullImages => number(obj(player['wallet'])['full_image_uses']);
  int get stars => number(player['stars']);
  bool get authenticated => api.token != null;
  bool get guest => player['is_guest'] == true;
  String get displayName => '${player['name'] ?? (arabic ? 'ضيف' : 'Guest')}';
  String tr(String ar, String en) => arabic ? ar : en;

  Future<void> initialize() async {
    ready = false;
    offline = false;
    status = null;
    notifyListeners();
    try {
      final prefs = await SharedPreferences.getInstance();
      arabic = prefs.getBool('puzzlequest.arabic') ?? true;
      reduceMotion = prefs.getBool('puzzlequest.reduce_motion') ?? false;
      soundEnabled = prefs.getBool('puzzlequest.sound_enabled') ?? true;
      hapticsEnabled = prefs.getBool('puzzlequest.haptics_enabled') ?? true;
      final cached = prefs.getString('puzzlequest.catalog');
      if (cached != null) {
        try { _readCatalog(obj(jsonDecode(cached))); } catch (_) {}
      }
      api.token = await _secure.read(key: tokenKey);
      if (api.token != null) {
        try {
          player = await api.get('me');
          await refreshCatalog();
        } catch (e) { offline = true; status = '$e'; }
      }
      if (levels.isEmpty) levels = await LocalCatalog.load();
    } catch (error) {
      offline = true;
      status = error.toString();
    } finally { ready = true; notifyListeners(); }
  }

  Future<T> run<T>(Future<T> Function() task) async {
    busy = true; status = null; notifyListeners();
    try { final result = await task(); offline = false; return result; }
    on ApiException catch (e) { if (e.status == 0) offline = true; status = e.message; rethrow; }
    finally { busy = false; notifyListeners(); }
  }

  Future<void> setLanguage(bool isArabic) async {
    arabic = isArabic; notifyListeners();
    (await SharedPreferences.getInstance()).setBool('puzzlequest.arabic', isArabic);
  }

  /// These are presentation/device preferences. They cannot influence scoring
  /// or server-authoritative economy and are intentionally account-independent.
  Future<void> setReduceMotion(bool value) async {
    reduceMotion=value; notifyListeners();
    await (await SharedPreferences.getInstance()).setBool('puzzlequest.reduce_motion',value);
  }
  Future<void> setSoundEnabled(bool value) async {
    soundEnabled=value; notifyListeners();
    await (await SharedPreferences.getInstance()).setBool('puzzlequest.sound_enabled',value);
  }
  Future<void> setHapticsEnabled(bool value) async {
    hapticsEnabled=value; notifyListeners();
    await (await SharedPreferences.getInstance()).setBool('puzzlequest.haptics_enabled',value);
  }

  Future<void> _authorize(Map<String, dynamic> response) async {
    if (response['state'] == 'mandatory_email_otp') throw const ApiException(423, 'mandatory_email_otp');
    final next = response['access_token'];
    if (next is! String || next.isEmpty) throw const FormatException('Missing session token');
    if (guest && api.token != null) previousGuestToken = api.token;
    api.token = next;
    await _secure.write(key: tokenKey, value: next);
    player = obj(response['player']);
    notifyListeners();
    await refreshCatalog();
  }
  Map<String,dynamic> get device => {'device_name':'PuzzleQuest Mobile',
    'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'};
  Future<void> startGuest({required bool ageConfirmed}) => run(() async => _authorize(await api.post('auth/guest', {
    ...device, 'age_confirmed_13': ageConfirmed,
  }, false)));
  Future<Map<String,dynamic>> login(String email,String password) => run(() async {
    final result = await api.post('auth/login', {...device,'email':email,'password':password},false);
    if (result['state'] != 'mandatory_email_otp') await _authorize(result);
    return result;
  });
  Future<Map<String,dynamic>> register(String name,String email,String password,
    {required String termsVersion,required bool ageConfirmed,required bool termsAccepted}) => run(() async {
    final originalGuestId=guest?player['id']:null;
    final result = await api.post('auth/register', {
      ...device,'name':name,'email':email,'password':password,
      'password_confirmation':password,'age_confirmed_13':ageConfirmed,
      'terms_accepted':termsAccepted,'terms_version':termsVersion,
    });
    await _authorize(result);
    // Upgrading the same guest identity is not a merge into a different user.
    // The server has already preserved this guest's balances/progress.
    if(originalGuestId!=null && player['id']==originalGuestId){
      previousGuestToken=null;
    }
    return result;
  });
  Future<Map<String,dynamic>> requestOtp(String email,String purpose) => run(() async =>
    api.post('auth/otp/request',{'email':email,'purpose':purpose},false));
  Future<void> verifyOtp(String challenge,String code,String purpose) => run(() async {
    final result = await api.post('auth/otp/verify',{
      ...device,'challenge_id':challenge,'code':code,'purpose':purpose},false);
    await _authorize(result);
  });
  Future<void> resetPassword(String challenge,String code,String password) => run(() async {
    await api.post('auth/password/reset',{
      'challenge_id':challenge,'code':code,'password':password,
      'password_confirmation':password,
    });
  });
  Future<void> logout() => run(() async {
    try { await api.post('auth/logout',{}); } catch (_) {}
    try {await _pushService?.disable();}catch(_){}
    api.token = null;player={};levels=await LocalCatalog.load();worlds=[];
    await _secure.delete(key:tokenKey);
    notifyListeners();
  });
  Future<void> logoutLocalAfterRevocation() async {
    try {await _pushService?.disable();}catch(_){}
    // The deletion endpoint revoked the server session. Never call auth/logout
    // or refreshPlayer with a token which has just been invalidated.
    api.token=null;player={};levels=await LocalCatalog.load();worlds=[];
    await _secure.delete(key:tokenKey);notifyListeners();
  }
  Future<void> mergeGuest() => run(() async {
    final token = previousGuestToken;
    if (token == null) return;
    player = await api.post('account/merge',{'guest_token':token,'confirm':true});
    previousGuestToken = null;notifyListeners();
  });
  Future<void> refreshPlayer() async {
    if (!authenticated) return;
    player = await api.get('me');notifyListeners();
  }
  void _readCatalog(Map<String,dynamic> envelope) {
    final inner = obj(envelope['catalog']);
    if (inner['schema_version'] != 1) throw const FormatException('Unsupported content schema');
    final data = arr(inner['levels']).map((e)=>LevelSpec.fromCatalog(obj(e))).toList();
    if (data.isEmpty) throw const FormatException('Empty content catalog');
    levels = data;worlds=arr(inner['worlds']); catalogData = inner;notifyListeners();
  }
  Future<void> refreshCatalog() async {
    if (!authenticated) return;
    final result = await api.get('catalog');
    _readCatalog(result);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('puzzlequest.catalog',jsonEncode(result));
  }
  LevelSpec? level(String id) {
    for (final level in levels) { if (level.id == id) return level; }
    return null;
  }
  Future<Map<String,dynamic>> fetch(String key,String endpoint) => run(() async {
    final data = await api.get(endpoint);
    _cache[key]=data; notifyListeners();return data;
  });
  Map<String,dynamic> cached(String key) => obj(_cache[key]);
  Future<Map<String,dynamic>> mutate(String endpoint,[Map<String,dynamic> data=const {}]) => run(() async {
    final response = await api.post(endpoint,data);
    await refreshPlayer();return response;
  });
  Future<void> saveProfile(Map<String,dynamic> changes) => run(() async {
    player = await api.patch('account/profile',changes);notifyListeners();
  });
  Future<void> configurePush(bool consent) async {
    _pushService ??= PushService(this);
    if(consent){await _pushService!.configure(userConsent:true);}
    else{await _pushService!.disable();}
  }
  @override
  void dispose() {_pushService?.dispose();api.dispose();super.dispose();}
}
