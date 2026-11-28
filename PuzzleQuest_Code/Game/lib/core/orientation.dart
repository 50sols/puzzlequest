import 'package:flutter/services.dart';

/// One supported orientation across gameplay, menu, overlays and startup.
/// This must run before the first Flutter frame is rendered.
Future<void> lockPuzzleQuestPortrait() =>
    SystemChrome.setPreferredOrientations(const [DeviceOrientation.portraitUp]);
