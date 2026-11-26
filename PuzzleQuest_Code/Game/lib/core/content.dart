import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'models.dart';

/// Byte-verified content cache. Files are immutable per revision and never
/// loaded from arbitrary URLs: the catalog must supply an HTTPS URL and digest.
class ContentStore {
  ContentStore({http.Client? client,Directory? cacheRoot}): _client = client ?? http.Client(),_cacheRoot=cacheRoot;
  final http.Client _client;
  final Directory? _cacheRoot;
  Future<Uint8List> bytes(LevelSpec level, String relativePath, {String? bundledPath}) async {
    final entry = obj(level.assets[relativePath]);
    if (entry.isEmpty) {
      if (bundledPath == null) throw const FormatException('Missing content asset');
      final data = await rootBundle.load(bundledPath);
      return data.buffer.asUint8List();
    }
    final rawUrl = '${entry['url'] ?? ''}';
    final digest = '${entry['sha256'] ?? ''}'.toLowerCase();
    var uri = Uri.tryParse(rawUrl);
    // A reverse proxy may advertise HTTP for our own asset host. Always
    // download over HTTPS while retaining the catalog's pinned checksum.
    if (uri?.host == 'puzzlequest.50sols.com' && uri?.scheme == 'http') {
      uri = uri!.replace(scheme:'https');
    }
    if (uri == null || uri.scheme != 'https' || digest.length != 64 ||
        uri.host != 'puzzlequest.50sols.com' || relativePath.contains('..')) {
      throw const FormatException('Untrusted content manifest');
    }
    final root = _cacheRoot ?? await getApplicationSupportDirectory();
    final dir = Directory('${root.path}/puzzlequest_content/${level.id}/${level.revision}');
    await dir.create(recursive: true);
    // Hash-based names avoid traversal and preserve revision immutability.
    final file = File('${dir.path}/$digest');
    if (await file.exists()) {
      final b = await file.readAsBytes();
      if (sha256.convert(b).toString() == digest) return b;
      await file.delete();
    }
    final response = await _client.get(uri).timeout(const Duration(seconds: 25));
    if (response.statusCode != 200) throw StateError('Content download failed');
    final b = response.bodyBytes;
    if (sha256.convert(b).toString() != digest) throw StateError('Content integrity check failed');
    final temporary = File('${file.path}.partial');
    await temporary.writeAsBytes(b, flush: true);
    await temporary.rename(file.path);
    return b;
  }
  Future<Uint8List> master(LevelSpec level) async {
    if (!level.downloadable) return bytes(level,'master.png',bundledPath:level.bundledMaster);
    if (level.assets.containsKey('master.png')) return bytes(level,'master.png');
    var metadata = level.remoteManifest;
    if (metadata.isEmpty && level.assets.containsKey('manifest.json')) {
      metadata = obj(jsonDecode(utf8.decode(await bytes(level,'manifest.json'))));
    }
    final path = '${metadata['master_image_path'] ?? ''}';
    if (path.isEmpty || !level.assets.containsKey(path)) {
      throw const FormatException('Puzzle master image is missing from its catalog');
    }
    return bytes(level,path);
  }
  Future<PuzzleManifest> manifest(LevelSpec level) async {
    if (!level.downloadable) {
      return PuzzleManifest.fromMap(obj(jsonDecode(await rootBundle.loadString(level.bundledManifest))));
    }
    // Backend catalog exposes the content files, but launch-content stores the
    // puzzle manifest in the revision payload instead of publishing a JSON URL.
    // Runtime requires a manifest asset for newly published levels.
    if (level.remoteManifest.isNotEmpty) {
      final manifest = PuzzleManifest.fromMap(level.remoteManifest);
      if (!manifest.valid || manifest.pieces.length != level.pieceCount) throw const FormatException('Invalid content geometry');
      return manifest;
    }
    final entry = level.assets['manifest.json'];
    if (entry == null) throw const FormatException('Published level has no verifiable manifest.json');
    final b = await bytes(level, 'manifest.json');
    final manifest = PuzzleManifest.fromMap(obj(jsonDecode(utf8.decode(b))));
    if (!manifest.valid || manifest.pieces.length != level.pieceCount) {
      throw const FormatException('Invalid puzzle manifest');
    }
    return manifest;
  }
  void dispose()=>_client.close();
}
