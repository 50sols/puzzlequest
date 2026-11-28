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
  bool ready = false, busy = false, offline = false, offlineGuest = false, arabic = true;
  bool reduceMotion = false, soundEnabled = true, hapticsEnabled = true;
  String? status;
  Map<String,dynamic> player = {}, daily = {}, catalogData = {};
  List<LevelSpec> levels = const [];
  List<dynamic> worlds = const [];
  List<LevelSpec> _bundledLevels = const [];
  String? previousGuestToken;
  final Map<String, dynamic> _cache = {};

  int get coins => number(obj(player['wallet'])['coins']);
  int get hints => number(obj(player['wallet'])['hints']);
  int get shuffles => number(obj(player['wallet'])['shuffle_uses']);
  int get fullImages => number(obj(player['wallet'])['full_image_uses']);
  int get stars => number(player['stars']);
  bool get authenticated => api.token != null;
  bool get guest => player['is_guest'] == true;
  bool get practiceMode => offline || offlineGuest;
  String get displayName => '${player['name'] ?? (arabic ? 'ضيف' : 'Guest')}';
  String tr(String ar, String en) => arabic ? ar : en;

  /// Keep the signed-in user on the home screen during network outages.
  /// Bundled levels are independent practice content; no offline minting.
  void _useBundledLevels() {
    if (_bundledLevels.isEmpty) return;
    // All bundled stages are accessible in local practice, not as server unlocks.
    levels=_bundledLevels.map((level)=>level.withUnlocked(true)).toList();
    notifyListeners();
  }

  Future<void> initialize() async {
    ready=false;offline=false;status=null;notifyListeners();
    try {
      final prefs=await SharedPreferences.getInstance();
      arabic=prefs.getBool('puzzlequest.arabic')??true;
      reduceMotion=prefs.getBool('puzzlequest.reduce_motion')??false;
      soundEnabled=prefs.getBool('puzzlequest.sound_enabled')??true;
      hapticsEnabled=prefs.getBool('puzzlequest.haptics_enabled')??true;
      offlineGuest=prefs.getBool('puzzlequest.offline_guest')??false;
      _bundledLevels=await LocalCatalog.load();
      for(final key in const ['missions','collections','village','shop','rewards/daily','leaderboard/weekly']){
        final raw=prefs.getString('puzzlequest.cache.$key');
        if(raw!=null){try{_cache[key]=obj(jsonDecode(raw));}catch(_){}}
      }
      final cached=prefs.getString('puzzlequest.catalog');
      if(cached!=null){
        try{_readCatalog(obj(jsonDecode(cached)));}catch(_){}
      }
      final savedPlayer=await _secure.read(key:'puzzlequest.confirmed_player');
      if(savedPlayer!=null){
        try{player=obj(jsonDecode(savedPlayer));}catch(_){}
      }
      api.token=await _secure.read(key:tokenKey);
      if(api.token!=null){
        offlineGuest=false;
        try {
          player=await api.get('me');
          await _secure.write(key:'puzzlequest.confirmed_player',value:jsonEncode(player));
          await refreshCatalog();
          await _flushPendingAvatar();
        }on ApiException catch(error){
          offline=true;status=error.message;_useBundledLevels();
        }catch(error){
          offline=true;status='$error';_useBundledLevels();
        }
      }else if(offlineGuest){
        player={'name':'Guest','is_guest':true,'offline_practice':true,
          'avatar':prefs.getString('puzzlequest.pending_avatar')};
        offline=true;_useBundledLevels();
      }else{
        player={};
      }
      if(levels.isEmpty)levels=_bundledLevels;
    }catch(error){
      offline=true;status='$error';
      if(_bundledLevels.isNotEmpty)_useBundledLevels();
    }finally{ready=true;notifyListeners();}
  }

  Future<void> startOfflinePractice() async {
    _bundledLevels=_bundledLevels.isEmpty?await LocalCatalog.load():_bundledLevels;
    offline=true;offlineGuest=true;
    final prefs=await SharedPreferences.getInstance();
    await prefs.setBool('puzzlequest.offline_guest',true);
    player={'name':'Guest','is_guest':true,'offline_practice':true,
      'avatar':prefs.getString('puzzlequest.pending_avatar')};
    _useBundledLevels();
    notifyListeners();
  }

  Future<T> run<T>(Future<T> Function() task) async {
    busy = true; status = null; notifyListeners();
    try { final result = await task(); return result; }
    on ApiException catch (e) {
      if(e.status==0){offline=true;_useBundledLevels();}
      status=e.message;rethrow;
    }
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
    offlineGuest=false;offline=false;
    final prefs=await SharedPreferences.getInstance();
    await prefs.remove('puzzlequest.offline_guest');
    await _secure.write(key:'puzzlequest.confirmed_player',value:jsonEncode(player));
    notifyListeners();
    try{await refreshCatalog();}on ApiException catch(e){
      if(e.status==0){offline=true;_useBundledLevels();}
      // Authentication succeeded. A catalog outage must not make signup fail.
    }
    if(!offline)await _flushPendingAvatar();
  }
  Map<String,dynamic> get device => {'device_name':'PuzzleQuest Mobile',
    'platform': defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android'};
  Future<void> startGuest({required bool ageConfirmed}) async {
    if(!ageConfirmed)throw const ApiException(422,'age_confirmation_required');
    try{
      await run(() async => _authorize(await api.post('auth/guest',{
        ...device,'age_confirmed_13':ageConfirmed,
      },false)));
    }on ApiException catch(e){
      if(e.status!=0)rethrow;
      await startOfflinePractice();
    }
  }
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
    api.token = null;player={};offlineGuest=false;offline=false;
    levels=await LocalCatalog.load();worlds=[];_cache.clear();
    final prefs=await SharedPreferences.getInstance();
    await _secure.delete(key:'puzzlequest.confirmed_player');
    await prefs.remove('puzzlequest.offline_guest');
    await prefs.remove('puzzlequest.pending_avatar');
    await _secure.delete(key:tokenKey);
    notifyListeners();
  });
  Future<void> logoutLocalAfterRevocation() async {
    try {await _pushService?.disable();}catch(_){}
    // The deletion endpoint revoked the server session. Never call auth/logout
    // or refreshPlayer with a token which has just been invalidated.
    api.token=null;player={};offlineGuest=false;offline=false;
    levels=await LocalCatalog.load();worlds=[];_cache.clear();
    final prefs=await SharedPreferences.getInstance();
    await _secure.delete(key:'puzzlequest.confirmed_player');
    await prefs.remove('puzzlequest.offline_guest');
    await prefs.remove('puzzlequest.pending_avatar');
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
    player = await api.get('me');
    await _secure.write(key:'puzzlequest.confirmed_player',value:jsonEncode(player));
    await _flushPendingAvatar();notifyListeners();
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
    offline=false;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('puzzlequest.catalog',jsonEncode(result));
  }
  LevelSpec? localLevel(String id) {
    for(final entry in _bundledLevels){if(entry.id==id)return entry.withUnlocked(true);}
    return null;
  }
  LevelSpec? level(String id) {
    for (final level in levels) { if (level.id == id) return level; }
    return null;
  }
  Future<Map<String,dynamic>> fetch(String key,String endpoint) async {
    const safeCache={'missions','collections','village','shop','rewards/daily','leaderboard/weekly'};
    if(offline && safeCache.contains(key))return cached(key);
    try {
      final data=await api.get(endpoint);
      if(safeCache.contains(key)){
        _cache[key]=data;
        await (await SharedPreferences.getInstance())
          .setString('puzzlequest.cache.$key',jsonEncode(data));
      }
      offline=false;notifyListeners();return data;
    }on ApiException catch(e){
      if(e.status==0){offline=true;_useBundledLevels();}
      if(safeCache.contains(key) && _cache.containsKey(key))return cached(key);
      rethrow;
    }
  }
  Map<String,dynamic> cached(String key) => obj(_cache[key]);
  Future<Map<String,dynamic>> mutate(String endpoint,[Map<String,dynamic> data=const {}]) => run(() async {
    final response = await api.post(endpoint,data);
    await refreshPlayer();return response;
  });
  Future<void> saveProfile(Map<String,dynamic> changes) => run(() async {
    player = await api.patch('account/profile',changes);
    await _secure.write(key:'puzzlequest.confirmed_player',value:jsonEncode(player));
    notifyListeners();
  });

  /// Avatar selection is usable offline. Pending changes never affect coins,
  /// progression or verified server rewards.
  Future<void> chooseAvatar(String avatar) async {
    const ids={'explorer_boy_blue','explorer_boy_glasses',
      'explorer_elder_scout','explorer_elder_turquoise',
      'explorer_girl_orange','explorer_girl_purple',
      'explorer_man_orange','explorer_woman_yellow'};
    if(!ids.contains(avatar))throw const FormatException('Invalid avatar');
    player={...player,'avatar':avatar};
    final prefs=await SharedPreferences.getInstance();
    await prefs.setString('puzzlequest.pending_avatar',avatar);
    notifyListeners();
    if(authenticated && !offline) await _flushPendingAvatar();
  }

  Future<void> _flushPendingAvatar() async {
    if(!authenticated || offline)return;
    final prefs=await SharedPreferences.getInstance();
    final pending=prefs.getString('puzzlequest.pending_avatar');
    if(pending==null || pending.isEmpty)return;
    try{
      player=await api.patch('account/profile',{'avatar':pending});
      await prefs.remove('puzzlequest.pending_avatar');
      await _secure.write(key:'puzzlequest.confirmed_player',value:jsonEncode(player));
      notifyListeners();
    }on ApiException catch(e){
      if(e.status==0){offline=true;_useBundledLevels();}
      // Retain the queued choice; the next authenticated refresh retries it.
      player={...player,'avatar':pending};notifyListeners();
    }
  }
  Future<void> configurePush(bool consent) async {
    _pushService ??= PushService(this);
    if(consent){await _pushService!.configure(userConsent:true);}
    else{await _pushService!.disable();}
  }
  @override
  void dispose() {_pushService?.dispose();api.dispose();super.dispose();}
}
