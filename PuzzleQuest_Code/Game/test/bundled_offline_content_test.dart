import 'package:flutter_test/flutter_test.dart';
import 'package:puzzlequest_game/core/content.dart';
import 'package:puzzlequest_game/core/models.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all launch puzzle masters and pieces can load without network', () async {
    final levels=await LocalCatalog.load();
    expect(levels.length,greaterThanOrEqualTo(5));
    expect(levels.any((level)=>level.pieceCount==16),true);
    expect(levels.any((level)=>level.pieceCount==36),true);
    expect(levels.any((level)=>level.pieceCount==64),true);
    expect(levels.any((level)=>level.pieceCount==100),true);
    final content=ContentStore();
    try {
      for(final level in levels) {
        expect(level.downloadable,false,reason:'Bundled launch art must work offline');
        final manifest=await content.manifest(level);
        expect(manifest.valid,true,reason:level.code);
        expect(manifest.pieces.length,level.pieceCount);
        final master=await content.master(level);
        expect(master.length,greaterThan(8),reason:'${level.code} master');
        for(final piece in manifest.pieces){
          final bytes=await content.bytes(level,piece.imagePath,
            bundledPath:level.bundledPiece(piece));
          expect(bytes.length,greaterThan(8),
            reason:'${level.code} ${piece.imagePath}');
        }
      }
    }finally{content.dispose();}
  });
}
