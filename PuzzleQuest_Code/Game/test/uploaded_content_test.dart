import 'dart:io';
import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:puzzlequest_game/core/content.dart';
import 'package:puzzlequest_game/core/models.dart';

void main() {
  test('Uploaded master uses manifest path, HTTPS and pinned checksum',() async {
    final root=await Directory.systemTemp.createTemp('pq-content-test');
    addTearDown(()=>root.delete(recursive:true));
    final payload=[1,2,3,4];
    final level=LevelSpec.fromCatalog({
      'id':'uploaded_six','display_code':'1-6','world_id':'green_valley',
      'piece_count':16,'unlocked':true,'revision':'r1',
      'manifest':{'master_image_path':'images/uploaded.png'},
      'assets':{'images/uploaded.png':{
        'url':'http://puzzlequest.50sols.com/content/six/images/uploaded.png',
        'sha256':sha256.convert(payload).toString()}},
    });
    var requests=0;
    final store=ContentStore(cacheRoot:root,client:MockClient((request) async {
      requests++;
      expect(request.url.scheme,'https');
      expect(request.url.path,endsWith('/images/uploaded.png'));
      return http.Response.bytes(payload,200);
    }));
    addTearDown(store.dispose);
    expect(await store.master(level),payload);
    expect(await store.master(level),payload);
    expect(requests,1);
  });
}
