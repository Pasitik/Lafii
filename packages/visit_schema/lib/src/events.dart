/// An append-only clinical event. Never edited, never deleted.
class ClinicalEvent {
  final String id;
  final DateTime at;
  final String kind;
  final String entityId;
  final Map<String, Object?> data;

  const ClinicalEvent({
    required this.id,
    required this.at,
    required this.kind,
    required this.entityId,
    this.data = const {},
  });

  Map<String, Object?> toJson() => {
        'id': id,
        'at': at.toIso8601String(),
        'kind': kind,
        'entityId': entityId,
        'data': data,
      };

  factory ClinicalEvent.fromJson(Map<String, Object?> j) => ClinicalEvent(
        id: j['id'] as String,
        at: DateTime.parse(j['at'] as String),
        kind: j['kind'] as String,
        entityId: j['entityId'] as String,
        data: (j['data'] as Map?)?.cast<String, Object?>() ?? const {},
      );
}

/// Merges two event logs from different devices.
///
/// The result is the union by event id, ordered by time then id. When both
/// sides hold the same id the local copy is kept; nothing is ever dropped.
/// Clinical events are append-only, so there is no last-writer-wins here.
List<ClinicalEvent> mergeEventLogs(
    List<ClinicalEvent> local, List<ClinicalEvent> remote) {
  final byId = <String, ClinicalEvent>{};
  for (final e in remote) {
    byId[e.id] = e;
  }
  for (final e in local) {
    byId[e.id] = e;
  }
  final out = byId.values.toList()
    ..sort((a, b) {
      final c = a.at.compareTo(b.at);
      return c != 0 ? c : a.id.compareTo(b.id);
    });
  return out;
}
