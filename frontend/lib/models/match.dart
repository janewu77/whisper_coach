import 'lineup.dart';

class Match {
  final int id;
  final int teamId;
  final String opponent;
  final String location;
  final String date;
  final String? notes;
  final String? strength; // 'strong' | 'weak' | null

  const Match({
    required this.id,
    required this.teamId,
    required this.opponent,
    required this.location,
    required this.date,
    this.notes,
    this.strength,
  });

  factory Match.fromJson(Map<String, dynamic> j) {
    final notes = j['notes'];
    return Match(
      id: j['id'] as int,
      teamId: j['team_id'] as int,
      opponent: j['opponent'] as String,
      location: j['location'] as String,
      date: j['date'] as String,
      // Match detail responses use "notes" for the event list, while list and
      // create responses use it for the optional setup note.
      notes: notes is String ? notes : null,
      strength: j['strength'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'team_id': teamId,
        'opponent': opponent,
        'location': location,
        'date': date,
        if (notes != null) 'notes': notes,
        if (strength != null) 'strength': strength,
      };
}

/// One match parsed from a photo/voice, shown in the create-review list.
class MatchDraft {
  String opponent;
  String? date;
  String? location;
  String? strength;
  String? notes;

  MatchDraft({this.opponent = '', this.date, this.location, this.strength, this.notes});

  factory MatchDraft.fromJson(Map<String, dynamic> j) => MatchDraft(
        opponent: (j['opponent'] as String?) ?? '',
        date: j['date'] as String?,
        location: j['location'] as String?,
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
