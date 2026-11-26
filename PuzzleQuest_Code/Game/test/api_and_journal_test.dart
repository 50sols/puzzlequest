import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:puzzlequest_game/core/api.dart';
import 'package:puzzlequest_game/core/models.dart';
import 'package:puzzlequest_game/core/offline_journal.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('API retry reuses an explicit idempotency key', () async {
    final seen=<String>[];
    final api=ApiClient(client:MockClient((req) async {
      seen.add(req.headers['Idempotency-Key'] ?? '');
      expect(req.url.host,'puzzlequest.50sols.com');
      return http.Response(jsonEncode({'ok':true}),200,
        headers:{'content-type':'application/json'});
    }));
    await api.postWithKey('shop/purchases',{'offer_id':'hint'},'reusable-operation-id');
    await api.postWithKey('shop/purchases',{'offer_id':'hint'},'reusable-operation-id');
    expect(seen,['reusable-operation-id','reusable-operation-id']);
    api.dispose();
  });

  test('private ZIP download stays authenticated and is verified', () async {
    final api=ApiClient(client:MockClient((req) async {
      expect(req.headers['Authorization'],'Bearer test-session');
      expect(req.followRedirects,false);
      expect(req.url.path,endsWith('/account/exports/123e4567-e89b-12d3-a456-426614174000/download'));
      return http.Response.bytes(Uint8List.fromList([0x50,0x4b,0x03,0x04,0,0]),200);
    }));
    api.token='test-session';
    final bytes=await api.downloadPrivateZip('123e4567-e89b-12d3-a456-426614174000');
    expect(bytes.length,6);
    api.dispose();
  });

  test('placement event journal preserves IDs before acknowledgement', () async {
    SharedPreferences.setMockInitialValues({});
    const p=PuzzlePieceSpec(id:'piece_000',imagePath:'16_pieces/piece_000.png',
      target:[0,0,100,100],anchor:[0,0]);
    final log=PlacementJournal('test-attempt');
    await log.add(p);
    await log.add(p);
    expect(log.events.length,1);
    final savedId=log.events.single['event_id'];
    final restored=await PlacementJournal.restore('test-attempt');
    expect(restored.events.single['event_id'],savedId);
    expect(restored.placed,contains('piece_000'));
    await restored.markAcknowledged();
    final afterAck=await PlacementJournal.restore('test-attempt');
    expect(afterAck.events,isEmpty);
    expect(afterAck.placed,contains('piece_000'));
    await afterAck.discardAfterServerConfirmation();
  });

  test('manifest refuses duplicate IDs and traversal paths', () {
    final m=PuzzleManifest.fromMap({
      'board_size_px':[960,960], 'snap_threshold_board_px':50,
      'pieces':[
        {'id':'piece_000','image_path':'../secret','target_rect_px':[0,0,300,300], 'snap_anchor_px':[0,0]},
        {'id':'piece_000','image_path':'piece.png','target_rect_px':[0,0,300,300], 'snap_anchor_px':[240,0]},
      ],
    });
    expect(m.valid,false);
  });
}
