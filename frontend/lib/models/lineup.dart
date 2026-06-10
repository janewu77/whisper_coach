class LineupSlot {
  final String player;
  final String position;
  // Nickname from the roster (attached server-side); null when unset.
  final String? nickname;

  const LineupSlot({
    required this.player,
    required this.position,
    this.nickname,
  });

  /// What to show on the pitch: the nickname when set, else the first name
  /// plus the last-name initial (e.g. "Thomas M.").
  String get displayName {
    if (nickname != null && nickname!.isNotEmpty) return nickname!;
    final parts = player.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return player;
    return '${parts.first} ${parts.last[0]}.';
  }

  factory LineupSlot.fromJson(Map<String, dynamic> j) => LineupSlot(
        player: j['player'] as String,
        position: j['position'] as String,
        nickname: j['nickname'] as String?,
      );

  Map<String, dynamic> toJson() => {
        'player': player,
        'position': position,
        if (nickname != null) 'nickname': nickname,
      };
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
