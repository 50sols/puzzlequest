import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import '../core/models.dart';

/// Flame owns render order and transparent PNG alpha composition of all placed
/// pieces; input and board-coordinate conversion are owned by Flutter's board
/// DragTarget. No rotation is performed: snap anchors remain in 960px space.
class PuzzleBoardGame extends FlameGame {
  PuzzleBoardGame(this.manifest, this.pieceImages, {this.restoredPieces = const []});
  final List<PuzzlePieceSpec> restoredPieces;
  final PuzzleManifest manifest;
  final Map<String, Uint8List> pieceImages;
  final Map<String, SpriteComponent> _components = {};
  final Map<String, PuzzlePieceSpec> _specs = {};
  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    for (final piece in restoredPieces) {
      await place(piece);
    }
  }

  @override
  void onGameResize(Vector2 size) {
    super.onGameResize(size);
    final scale = size.x / manifest.boardSize;
    for (final entry in _components.entries) {
      final piece = _specs[entry.key]!;
      entry.value.position = Vector2(piece.target[0]*scale,piece.target[1]*scale);
      entry.value.size = Vector2(piece.target[2]*scale,piece.target[3]*scale);
    }
  }

  Future<void> place(PuzzlePieceSpec piece) async {
    if (_components.containsKey(piece.id)) return;
    final bytes = pieceImages[piece.id];
    if (bytes == null) throw StateError('Missing piece image ${piece.id}');
    // dart:ui.decodeImageFromList takes a callback and returns void in Flutter
    // 3.47. Decode a single PNG frame explicitly and keep its Image for Flame.
    final codec = await ui.instantiateImageCodec(bytes);
    late final ui.Image image;
    try {
      image = (await codec.getNextFrame()).image;
    } finally {
      codec.dispose();
    }
    final scale = size.x > 0 ? size.x / manifest.boardSize : 1.0;
    final sprite = SpriteComponent(sprite:Sprite(image),
      position:Vector2(piece.target[0]*scale,piece.target[1]*scale),
      size:Vector2(piece.target[2]*scale,piece.target[3]*scale),
      priority:piece.id.hashCode & 0x7fffffff);
    _components[piece.id]=sprite;_specs[piece.id]=piece;
    await add(sprite);
  }
}
