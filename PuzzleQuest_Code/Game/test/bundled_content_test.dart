import 'dart:convert';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:puzzlequest_game/core/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Five published Green Valley levels follow approved piece counts and timers', () async {
    final levels=await LocalCatalog.load();
    expect(levels.length,5);
    expect(levels.map((e)=>e.pieceCount).toList(),[16,16,36,64,100]);
    expect(levels.map((e)=>e.limit).toList(),[360,360,600,1080,1800]);
    expect(levels.map((e)=>e.three).toList(),[150,150,270,480,900]);
    expect(levels.map((e)=>e.two).toList(),[270,270,450,840,1440]);
    for (final level in levels) {
      expect(level.published,isTrue);
      expect(level.worldId,'green_valley');
      final manifest=PuzzleManifest.fromMap(Map<String,dynamic>.from(jsonDecode(
        await rootBundle.loadString(level.bundledManifest))));
      expect(manifest.valid,isTrue,reason:level.code);
      expect(manifest.pieces.length,level.pieceCount,reason:level.code);
      final ids=<String>{};
      for (final piece in manifest.pieces) {
        expect(ids.add(piece.id),isTrue);
        expect(piece.target.length,4);
        expect(piece.anchor.length,2);
        final image=await rootBundle.load(level.bundledPiece(piece));
        expect(image.lengthInBytes,greaterThan(0),reason:piece.id);
      }
    }
  });
}
