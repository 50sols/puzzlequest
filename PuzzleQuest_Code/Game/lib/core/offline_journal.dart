import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';
import 'models.dart';

/// Append-only local placement journal; never claims rewards locally.
class PlacementJournal {
  PlacementJournal(this.attemptId, {this.offlineTicket=false});
  final String attemptId;
  final bool offlineTicket;
  final List<Map<String,dynamic>> events = [];
  final Set<String> placed = {};
  static const _uuid = Uuid();
  int elapsedMs = 0;
  bool serverConfirmed = false;
  /// Events are persisted before submission; an uncertain request may be
  /// retried using the same IDs, never a second wallet/placement operation.
  Future<void> markAcknowledged() async {
    events.clear();
    await persist();
  }
  Future<void> add(PuzzlePieceSpec p) async {
    if (!placed.add(p.id)) return;
    events.add({'event_id':_uuid.v4(),'piece_id':p.id,'anchor':p.anchor});
    await persist();
  }
  Future<void> persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('pq.attempt.$attemptId',jsonEncode({
      'attempt_id':attemptId,'offline_ticket':offlineTicket,
      'events':events,'placed':placed.toList(),'elapsed_ms':elapsedMs,
    }));
  }
  static Future<PlacementJournal> restore(String attemptId) async {
    final prefs=await SharedPreferences.getInstance();
    final json=prefs.getString('pq.attempt.$attemptId');
    if (json==null) return PlacementJournal(attemptId);
    final data=obj(jsonDecode(json));
    final journal=PlacementJournal(attemptId, offlineTicket:data['offline_ticket']==true);
    journal.events.addAll(arr(data['events']).map((x)=>obj(x)));
    journal.placed.addAll(arr(data['placed']).map((x)=>'$x'));
    journal.elapsedMs=number(data['elapsed_ms']);
    return journal;
  }
  Future<void> discardAfterServerConfirmation() async {
    serverConfirmed=true;
    await (await SharedPreferences.getInstance()).remove('pq.attempt.$attemptId');
  }
}
