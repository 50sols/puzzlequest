import 'dart:convert';
import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puzzlequest_game/core/content.dart';
import 'package:puzzlequest_game/core/models.dart';

const _revision = 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa-bbbbbbbbbbbb';
final _direct = Uri.parse('https://puzzlequest.50sols.com/content/green_valley_house_001/$_revision/master.png');
final _gateway = Uri.parse('https://puzzlequest.50sols.com/api/v1/content/green_valley_house_001/$_revision/master.png');
final _picture = utf8.encode('verified published PNG bytes');

LevelSpec _level({String? digest, String? url}) => LevelSpec.fromCatalog({
  'id': 'green_valley_house_001',
  'display_code': '1-1',
  'world_id': 'green_valley',
  'revision': _revision,
  'piece_count': 16,
  'level_time_limit_seconds': 360,
  'three_star_seconds': 120,
  'two_star_seconds': 240,
  'unlocked': true,
  'assets': {
    'master.png': {
      'url': url ?? _direct.toString(),
      'sha256': digest ?? sha256.convert(_picture).toString(),
    },
  },
});

Future<Directory> _cache() async {
  final cache = await Directory.systemTemp.createTemp('pq-content-download-');
  addTearDown(() async {
    if (await cache.exists()) await cache.delete(recursive: true);
  });
  return cache;
}

void main() {
  test('404 from direct cPanel asset retries published HTTPS gateway with same hash', () async {
    final seen = <Uri>[];
    final store = ContentStore(
      cacheRoot: await _cache(),
      client: MockClient((request) async {
        seen.add(request.url);
        if (request.url == _gateway) return http.Response.bytes(_picture, 200);
        return http.Response('not found', 404);
      }),
    );
    addTearDown(store.dispose);
    expect(await store.bytes(_level(), 'master.png'), _picture);
    expect(seen, [_direct, _gateway]);
    // The immutable checksum cache must avoid downloading the same file twice.
    expect(await store.bytes(_level(), 'master.png'), _picture);
    expect(seen, [_direct, _gateway]);
  });

  test('both asset routes failing names the missing file and HTTP status', () async {
    final store = ContentStore(
      cacheRoot: await _cache(),
      client: MockClient((request) async =>
          http.Response('not found', request.url == _gateway ? 403 : 404)),
    );
    addTearDown(store.dispose);
    await expectLater(
      store.bytes(_level(), 'master.png'),
      throwsA(predicate((error) =>
        error is StateError &&
        error.toString().contains('master.png') &&
        error.toString().contains('HTTP 403'))),
    );
  });

  test('gateway response is rejected unless it matches published SHA-256', () async {
    final store = ContentStore(
      cacheRoot: await _cache(),
      client: MockClient((request) async =>
          request.url == _gateway
            ? http.Response.bytes(utf8.encode('wrong bytes'), 200)
            : http.Response('not found', 404)),
    );
    addTearDown(store.dispose);
    await expectLater(
      store.bytes(_level(), 'master.png'),
      throwsA(isA<StateError>().having(
          (error) => error.toString(), 'error', contains('integrity'))),
    );
  });

  test('foreign host is never fetched or retried through our gateway', () async {
    var requests = 0;
    final store = ContentStore(
      cacheRoot: await _cache(),
      client: MockClient((request) async {
        requests++;
        return http.Response.bytes(_picture, 200);
      }),
    );
    addTearDown(store.dispose);
    await expectLater(
      store.bytes(_level(url: 'https://attacker.invalid/master.png'), 'master.png'),
      throwsA(isA<FormatException>()),
    );
    expect(requests, 0);
  });
}
