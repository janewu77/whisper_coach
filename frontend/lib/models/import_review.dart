import 'player.dart';

/// A single changed field on an "updated" import item (before → after).
class FieldChange {
  final String field; // 'name' | 'number' | 'preferred_position'
  final String? before;
  final String? after;

  const FieldChange({required this.field, this.before, this.after});

  factory FieldChange.fromJson(Map<String, dynamic> j) => FieldChange(
        field: j['field'] as String,
        before: j['before'] as String?,
        after: j['after'] as String?,
      );

  /// Human label for the field name.
  String get label => switch (field) {
        'name' => 'Name',
        'number' => 'Jersey Number',
        'preferred_position' => 'Position',
        _ => field,
      };
}

/// One reviewed player inside an import session (not yet in the database).
class ImportItem {
  final int id;
  final String name;
  final int? number;
  final String? preferredPosition;
  final String classification; // new | updated | duplicate | unchanged
  final double? confidence; // 0..1, for duplicate candidates
  final String? rationale;
  final bool deleted;
  final Player? match; // the existing player this maps to
  final int? matchPlayerId;
  final List<FieldChange> changes;

  const ImportItem({
    required this.id,
    required this.name,
    this.number,
    this.preferredPosition,
    required this.classification,
    this.confidence,
    this.rationale,
    this.deleted = false,
    this.match,
    this.matchPlayerId,
    this.changes = const [],
  });

  /// Confidence as a whole-number percent, e.g. 92.
  int? get confidencePercent =>
      confidence == null ? null : (confidence! * 100).round();

  factory ImportItem.fromJson(Map<String, dynamic> j) => ImportItem(
        id: j['id'] as int,
        name: j['name'] as String,
        number: j['number'] as int?,
        preferredPosition: j['preferred_position'] as String?,
        classification: j['classification'] as String,
        confidence: (j['confidence'] as num?)?.toDouble(),
        rationale: j['rationale'] as String?,
        deleted: j['deleted'] as bool? ?? false,
        match: j['match'] == null
            ? null
            : Player.fromJson(Map<String, dynamic>.from(j['match'] as Map)),
        matchPlayerId: j['match_player_id'] as int?,
        changes: ((j['changes'] as List<dynamic>?) ?? const [])
            .map((c) => FieldChange.fromJson(Map<String, dynamic>.from(c as Map)))
            .toList(),
      );
}

/// The full grouped import review returned by the backend.
class ImportReview {
  final int sessionId;
  final int teamId;
  final String status;
  final List<ImportItem> newPlayers;
  final List<ImportItem> updatedPlayers;
  final List<ImportItem> duplicateCandidates;
  final List<ImportItem> unchangedPlayers;
  final String? reply; // optional message from an AI command

  const ImportReview({
    required this.sessionId,
    required this.teamId,
    required this.status,
    this.newPlayers = const [],
    this.updatedPlayers = const [],
    this.duplicateCandidates = const [],
    this.unchangedPlayers = const [],
    this.reply,
  });

  /// Number of players that will be written on confirm (everything except
  /// unchanged players).
  int get importCount =>
      newPlayers.length + updatedPlayers.length + duplicateCandidates.length;

  int get totalCount => importCount + unchangedPlayers.length;

  static List<ImportItem> _items(dynamic v) =>
      ((v as List<dynamic>?) ?? const [])
          .map((e) => ImportItem.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();

  factory ImportReview.fromJson(Map<String, dynamic> j) => ImportReview(
        sessionId: j['session_id'] as int,
        teamId: j['team_id'] as int,
        status: j['status'] as String,
        newPlayers: _items(j['new_players']),
        updatedPlayers: _items(j['updated_players']),
        duplicateCandidates: _items(j['duplicate_candidates']),
        unchangedPlayers: _items(j['unchanged_players']),
        reply: j['reply'] as String?,
      );
}

/// Result of confirming an import.
class ImportConfirm {
  final int created;
  final int updated;
  final int skipped;

  const ImportConfirm({
    required this.created,
    required this.updated,
    required this.skipped,
  });

  factory ImportConfirm.fromJson(Map<String, dynamic> j) => ImportConfirm(
        created: j['created'] as int,
        updated: j['updated'] as int,
        skipped: j['skipped'] as int,
      );
}
