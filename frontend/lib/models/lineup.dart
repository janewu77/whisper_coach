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
  // Bench, in recommended substitution order.
  final List<LineupSlot> subs;
  final String reason;

  const Lineup({
    required this.formation,
    required this.lineup,
    this.subs = const [],
    required this.reason,
  });

  factory Lineup.fromJson(Map<String, dynamic> j) => Lineup(
        formation: j['formation'] as String,
        lineup: (j['lineup'] as List<dynamic>)
            .map(
              (s) => LineupSlot.fromJson(
                Map<String, dynamic>.from(s as Map),
              ),
            )
            .toList(),
        subs: (j['subs'] as List<dynamic>? ?? const [])
            .map(
              (s) => LineupSlot.fromJson(
                Map<String, dynamic>.from(s as Map),
              ),
            )
            .toList(),
        reason: j['reason'] as String,
      );
}
