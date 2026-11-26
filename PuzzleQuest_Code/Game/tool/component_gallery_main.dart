import 'package:flutter/material.dart';
import 'package:puzzlequest_game/core/theme.dart';
import 'package:puzzlequest_game/widgets/component_preview.dart';

/// Developer-only entrypoint. Not in public PuzzleQuest navigation.
void main()=>runApp(MaterialApp(
  title:'PuzzleQuest Design Components — Developer Preview',
  theme:puzzleTheme(true),locale:const Locale('ar'),
  home:const PQComponentPreview(),
));
