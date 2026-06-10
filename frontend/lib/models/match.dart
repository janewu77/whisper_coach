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

class MatchDetails {
  final Match match;
  final Lineup? lineup;

  const MatchDetails({required this.match, this.lineup});

  factory MatchDetails.fromJson(Map<String, dynamic> json) {
    final lineupJson = json['lineup'];
    return MatchDetails(
      match: Match.fromJson(json),
      lineup: lineupJson is Map
          ? Lineup.fromJson(Map<String, dynamic>.from(lineupJson))
          : null,
    );
  }
}
