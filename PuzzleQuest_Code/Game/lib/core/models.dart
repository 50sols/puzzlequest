import 'dart:convert';
import 'package:flutter/services.dart';

Map<String, dynamic> obj(dynamic input) => input is Map
    ? Map<String, dynamic>.from(input) : <String, dynamic>{};
List<dynamic> arr(dynamic input) => input is List ? input : const [];
int number(dynamic input, [int fallback = 0]) => input is num ? input.toInt() : int.tryParse('$input') ?? fallback;
String localized(dynamic value, bool arabic) {
  if (value is Map) return '${value[arabic ? 'ar' : 'en'] ?? value['en'] ?? value['ar'] ?? ''}';
  return '${value ?? ''}';
}

class PuzzlePieceSpec {
  const PuzzlePieceSpec({required this.id, required this.imagePath,
    required this.target, required this.anchor});
  final String id;
  final String imagePath;
  final List<double> target;
  final List<double> anchor;
  factory PuzzlePieceSpec.fromMap(Map<String,dynamic> data) => PuzzlePieceSpec(
    id: '${data['id']}',
    imagePath: '${data['image_path']}',
    target: arr(data['target_rect_px']).map((x)=>(x as num).toDouble()).toList(),
    anchor: arr(data['snap_anchor_px']).map((x)=>(x as num).toDouble()).toList(),
  );
}

class PuzzleManifest {
  const PuzzleManifest({required this.boardSize, required this.threshold, required this.pieces});
  final double boardSize;
  final double threshold;
  final List<PuzzlePieceSpec> pieces;
  factory PuzzleManifest.fromMap(Map<String,dynamic> data) => PuzzleManifest(
    boardSize: (arr(data['board_size_px']).first as num).toDouble(),
    threshold: (data['snap_threshold_board_px'] as num).toDouble(),
    pieces: arr(data['pieces']).map((x)=>PuzzlePieceSpec.fromMap(obj(x))).toList(),
  );
  bool get valid => pieces.isNotEmpty && boardSize > 0 && threshold > 0 &&
      pieces.every((p)=>p.id.isNotEmpty && !p.imagePath.contains('..') &&
        p.target.length == 4 && p.target[2] > 0 && p.target[3] > 0 &&
        p.anchor.length == 2 && p.anchor.every((v)=>v.isFinite && v>=0 && v<boardSize) &&
        p.target.every((v)=>v.isFinite)) &&
      pieces.map((e)=>e.id).toSet().length == pieces.length;
}

class LevelSpec {
  const LevelSpec({required this.id,required this.code,required this.worldId,
    required this.pieceCount,required this.limit,required this.three,required this.two,
    required this.assetFolder,required this.published,required this.unlocked,
    this.assets = const {}, this.revision = '', this.title = const {},this.remoteManifest = const {}});
  final String id, code, worldId, assetFolder, revision;
  final int pieceCount, limit, three, two;
  final bool published, unlocked;
  final Map<String,dynamic> title;
  /// Each content revision pins URL + SHA-256 for every file.
  final Map<String,dynamic> assets;
  final Map<String,dynamic> remoteManifest;
  factory LevelSpec.fromCatalog(Map<String,dynamic> data) => LevelSpec(
    id: '${data['id']}',code: '${data['display_code']}', worldId: '${data['world_id']}',
    assetFolder: '', pieceCount: number(data['piece_count']),
    limit: number(data['level_time_limit_seconds']),
    three: number(data['three_star_seconds']), two: number(data['two_star_seconds']),
    published: true, unlocked: data['unlocked'] == true,
    assets: obj(data['assets']), revision: '${data['revision'] ?? ''}',title: obj(data['title']),remoteManifest: obj(data['manifest']),
  );
  factory LevelSpec.fromBundle(Map<String,dynamic> data) => LevelSpec(
    id:'${data['level_id']}',code:'${data['display_code']}',worldId:'${data['world_id']}',
    assetFolder:'${data['level_folder']}',pieceCount:number(data['selected_piece_count']),
    limit:number(data['level_time_limit_seconds']),
    three:number(obj(data['rating_time_thresholds_seconds'])['three_stars']),
    two:number(obj(data['rating_time_thresholds_seconds'])['two_stars']),
    published:data['published_at_launch']==true,
    unlocked:number(data['world_level_number'])==1,
    title:{'en':'Level ${data['display_code']}','ar':'المرحلة ${data['display_code']}'},
  );
  String get bundledManifest => 'assets/puzzles/$assetFolder/$pieceCount.manifest.v1.json';
  String get bundledMaster => 'assets/puzzles/$assetFolder/master.png';
  String bundledPiece(PuzzlePieceSpec piece) => 'assets/puzzles/$assetFolder/${piece.imagePath}';
  bool get downloadable => assets.isNotEmpty;
}

class LocalCatalog {
  static Future<List<LevelSpec>> load() async {
    final data = obj(jsonDecode(await rootBundle.loadString('assets/config/level_catalog.json')));
    return arr(data['levels']).map((x)=>LevelSpec.fromBundle(obj(x))).toList();
  }
}

class PuzzleRating {
  static int calculate({required int activeSeconds,required int limit,
    required int three,required int two,required int aids,required bool completed}) {
    if (!completed || activeSeconds >= limit) return 0;
    if (aids == 0 && activeSeconds <= three) return 3;
    if (aids <= 1 && activeSeconds <= two) return 2;
    return 1;
  }
  static int score({required int activeSeconds,required int limit,required int aids,required bool completed}) {
    if (!completed || activeSeconds >= limit) return 0;
    final speed = (500 * (1 - activeSeconds / limit)).clamp(0, 500).floor();
    return (1000 + speed - aids * 100).clamp(0,1500);
  }
}
