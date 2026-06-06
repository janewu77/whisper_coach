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

  factory Match.fromJson(Map<String, dynamic> j) => Match(
        id: j['id'] as int,
        teamId: j['team_id'] as int,
        opponent: j['opponent'] as String,
        location: j['location'] as String,
        date: j['date'] as String,
        notes: j['notes'] as String?,
        strength: j['strength'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'team_id': teamId,
        'opponent': opponent,
        'location': location,
        'date': date,
        if (notes != null) 'notes': notes,
        if (strength != null) 'strength': strength,
      };
}
