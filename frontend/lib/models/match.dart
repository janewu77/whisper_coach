import 'lineup.dart';

class Match {
  final int id;
  final int teamId;
  final String opponent;
  final bool isHome; // our team plays at home?
  final String location;
  final String? pitch;
  final String? address;
  final String date;
  final String? kickoffTime; // "HH:MM"
  final String? notes;
  final String? strength; // 'strong' | 'weak' | null
  // Per-match availability override; null = derive from player absences.
  final List<int>? unavailablePlayerIds;

  const Match({
    required this.id,
    required this.teamId,
    required this.opponent,
    this.isHome = true,
    this.location = '',
    this.pitch,
    this.address,
    required this.date,
    this.kickoffTime,
    this.notes,
    this.strength,
    this.unavailablePlayerIds,
  });

  factory Match.fromJson(Map<String, dynamic> j) {
    final notes = j['notes'];
    return Match(
      id: j['id'] as int,
      teamId: j['team_id'] as int,
      opponent: j['opponent'] as String,
      isHome: (j['is_home'] as bool?) ?? true,
      location: (j['location'] as String?) ?? '',
      pitch: j['pitch'] as String?,
      address: j['address'] as String?,
      date: j['date'] as String,
      kickoffTime: j['kickoff_time'] as String?,
      // Match detail responses use "notes" for the event list, while list and
      // create responses use it for the optional setup note.
      notes: notes is String ? notes : null,
      strength: j['strength'] as String?,
      unavailablePlayerIds: (j['unavailable_player_ids'] as List<dynamic>?)
          ?.map((e) => e as int)
          .toList(),
    );
  }
}

/// One match parsed from a photo/voice, shown in the create-review list.
class MatchDraft {
  String opponent;
  bool isHome;
  String? date;
  String? kickoffTime;
  String? pitch;
  String? address;
  String? strength;
  String? notes;

  MatchDraft({
    this.opponent = '',
    this.isHome = true,
    this.date,
    this.kickoffTime,
    this.pitch,
    this.address,
    this.strength,
    this.notes,
  });

  factory MatchDraft.fromJson(Map<String, dynamic> j) => MatchDraft(
        opponent: (j['opponent'] as String?) ?? '',
        isHome: (j['is_home'] as bool?) ?? true,
        date: j['date'] as String?,
        kickoffTime: j['kickoff_time'] as String?,
        pitch: j['pitch'] as String?,
        address: j['address'] as String?,
        strength: j['strength'] as String?,
        notes: j['notes'] as String?,
      );
}

/// A stored in-match note (text or transcribed voice) with the AI response.
class MatchNote {
  final int id;
  final String kind; // 'text' | 'voice'
  final String content;
  final Map<String, dynamic>? aiResponse; // AdjustResult shape, may be empty
  final DateTime? createdAt;

  const MatchNote({
    required this.id,
    required this.kind,
    required this.content,
    this.aiResponse,
    this.createdAt,
  });

  factory MatchNote.fromJson(Map<String, dynamic> j) => MatchNote(
        id: j['id'] as int,
        kind: (j['kind'] as String?) ?? 'text',
        content: (j['content'] as String?) ?? '',
        aiResponse: j['ai_response'] is Map
            ? Map<String, dynamic>.from(j['ai_response'] as Map)
            : null,
        createdAt: j['created_at'] is String
            ? DateTime.tryParse(j['created_at'] as String)?.toLocal()
            : null,
      );
}

class MatchDetails {
  final Match match;
  final Lineup? lineup;
  final List<MatchNote> notes;

  const MatchDetails({required this.match, this.lineup, this.notes = const []});

  factory MatchDetails.fromJson(Map<String, dynamic> json) {
    final lineupJson = json['lineup'];
    return MatchDetails(
      match: Match.fromJson(json),
      lineup: lineupJson is Map
          ? Lineup.fromJson(Map<String, dynamic>.from(lineupJson))
          : null,
      notes: (json['notes'] is List)
          ? (json['notes'] as List)
              .whereType<Map>()
              .map((n) => MatchNote.fromJson(Map<String, dynamic>.from(n)))
              .toList()
          : const [],
    );
  }
}
