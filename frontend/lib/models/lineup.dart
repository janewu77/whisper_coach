class LineupSlot {
  final String player;
  final String position;

  const LineupSlot({required this.player, required this.position});

  factory LineupSlot.fromJson(Map<String, dynamic> j) => LineupSlot(
        player: j['player'] as String,
        position: j['position'] as String,
      );

  Map<String, dynamic> toJson() => {'player': player, 'position': position};
}

class Lineup {
  final String formation;
  final List<LineupSlot> lineup;
  final String reason;

  const Lineup({
    required this.formation,
    required this.lineup,
    required this.reason,
  });

  factory Lineup.fromJson(Map<String, dynamic> j) => Lineup(
        formation: j['formation'] as String,
        lineup: (j['lineup'] as List<dynamic>)
            .map((s) => LineupSlot.fromJson(s as Map<String, dynamic>))
            .toList(),
        reason: j['reason'] as String,
      );
}
