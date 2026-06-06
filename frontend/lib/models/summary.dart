class PlayerPerformance {
  final String player;
  final String rating;
  final String comment;

  const PlayerPerformance({
    required this.player,
    required this.rating,
    required this.comment,
  });

  factory PlayerPerformance.fromJson(Map<String, dynamic> j) =>
      PlayerPerformance(
        player: j['player'] as String,
        rating: j['rating'] as String,
        comment: j['comment'] as String,
      );
}

class Summary {
  final String summary;
  final List<PlayerPerformance> playerPerformance;
  final List<String> improvements;

  const Summary({
    required this.summary,
    required this.playerPerformance,
    required this.improvements,
  });

  factory Summary.fromJson(Map<String, dynamic> j) => Summary(
        summary: j['summary'] as String,
        playerPerformance: (j['player_performance'] as List<dynamic>)
            .map((p) => PlayerPerformance.fromJson(p as Map<String, dynamic>))
            .toList(),
        improvements:
            (j['improvements'] as List<dynamic>).cast<String>().toList(),
      );
}
