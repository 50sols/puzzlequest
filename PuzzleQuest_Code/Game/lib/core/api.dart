import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:uuid/uuid.dart';

/// Transport contract: Laravel /api/v1. Never embed credentials or OAuth secrets.
class ApiException implements Exception {
  const ApiException(this.status, this.message, [this.payload = const {}]);
  final int status;
  final String message;
  final Map<String, dynamic> payload;
  @override
  String toString() => 'API $status: $message';
}

Map<String,dynamic> objJson(dynamic value) => value is Map
  ? Map<String,dynamic>.from(value):<String,dynamic>{};

class ApiClient {
  ApiClient({http.Client? client, Uri? endpoint})
      : _http = client ?? http.Client(),
        endpoint = endpoint ?? Uri.parse('https://puzzlequest.50sols.com/api/v1/');
  final http.Client _http;
  final Uri endpoint;
  String? token;
  final _uuid = const Uuid();

  Uri url(String path) {
    final clean = path.replaceFirst(RegExp(r'^/+'), '');
    return endpoint.resolve(clean);
  }

  Future<Map<String, dynamic>> get(String path) => _send('GET', path);
  Future<Map<String, dynamic>> post(String path, [Map<String, dynamic> json = const {}, bool idempotent = true]) =>
      _send('POST', path, json, idempotent);
  Future<Map<String, dynamic>> patch(String path, [Map<String, dynamic> json = const {}]) =>
      _send('PATCH', path, json, true);
  /// Reuse the same operation ID for retried economic mutations.
  Future<Map<String, dynamic>> postWithKey(
          String path, Map<String, dynamic> json, String operationKey) =>
      _send('POST', path, json, true, operationKey);

  Future<Map<String, dynamic>> _send(String method, String path,
      [Map<String, dynamic>? body, bool idempotent = false, String? operationKey]) async {
    final headers = <String, String>{
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null) 'Authorization': 'Bearer $token',
      if (idempotent && method != 'GET') 'Idempotency-Key': operationKey ?? _uuid.v4(),
    };
    try {
      final request = http.Request(method, url(path));
      request.headers.addAll(headers);
      if (body != null) request.body = jsonEncode(body);
      final response = await http.Response.fromStream(await _http.send(request).timeout(const Duration(seconds: 20)));
      Map<String, dynamic> decoded;
      try {
        final value = jsonDecode(response.body);
        decoded = value is Map ? Map<String, dynamic>.from(value) : {'data': value};
      } catch (_) {
        throw ApiException(response.statusCode, 'Invalid server response');
      }
      if (response.statusCode < 200 || response.statusCode >= 300) {
        final detail = decoded['error'] ?? decoded['message'] ?? decoded['code'] ?? 'Request failed';
        throw ApiException(response.statusCode, '$detail', decoded);
      }
      return decoded;
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(0, 'Connection unavailable: $error');
    }
  }
  /// Fetch personal exports with the player's bearer token. Never move the
  /// token to a browser, redirect, or untrusted domain.
  Future<Uint8List> downloadPrivateZip(String exportId) async {
    if (!RegExp(r'^[0-9a-fA-F-]{36}$').hasMatch(exportId)) {
      throw const ApiException(400,'Invalid export identifier');
    }
    final request=http.Request('GET',url('account/exports/$exportId/download'));
    request.followRedirects=false;
    request.headers['Accept']='application/zip';
    if(token!=null)request.headers['Authorization']='Bearer $token';
    final result=await http.Response.fromStream(
      await _http.send(request).timeout(const Duration(seconds:50)));
    if(result.statusCode!=200)throw ApiException(result.statusCode,'Export is not yet available');
    final bytes=result.bodyBytes;
    if(bytes.length<4 || bytes[0]!=0x50 || bytes[1]!=0x4B) {
      throw const FormatException('Server did not return a ZIP archive');
    }
    return bytes;
  }

  /// User-chosen support image, attached using authenticated multipart data.
  Future<Map<String,dynamic>> multipartSupport({
    required Map<String,String> fields, Uint8List? image, String? filename,
  }) async {
    final req=http.MultipartRequest('POST',url('support/tickets'));
    req.followRedirects=false;
    req.headers['Accept']='application/json';
    if(token!=null)req.headers['Authorization']='Bearer $token';
    req.headers['Idempotency-Key']=_uuid.v4();
    req.fields.addAll(fields);
    if(image!=null){
      if(image.length>2*1024*1024)throw const ApiException(413,'Image must be below 2 MB');
      final ext=(filename??'image.jpg').split('.').last.toLowerCase();
      if(!['png','jpg','jpeg','webp'].contains(ext))throw const ApiException(400,'Unsupported image format');
      req.files.add(http.MultipartFile.fromBytes('image',image,filename:'support.$ext'));
    }
    final response=await http.Response.fromStream(
      await _http.send(req).timeout(const Duration(seconds:40)));
    Map<String,dynamic> data;
    try{data=objJson(jsonDecode(response.body));}
    catch(_){throw ApiException(response.statusCode,'Invalid support response');}
    if(response.statusCode<200||response.statusCode>=300){
      throw ApiException(response.statusCode,'${data['error']??data['message']??'Support request failed'}',data);
    }
    return data;
  }
  void dispose() => _http.close();
}
