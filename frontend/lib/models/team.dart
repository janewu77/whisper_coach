import 'player.dart';

class Team {
  final int id;
  final String name;
  final String? joinCode; // code other users enter to join this shared team
  final List<Player> players;

  const Team({
    required this.id,
    required this.name,
    this.joinCode,
    this.players = const [],
  });

  factory Team.fromJson(Map<String, dynamic> j) => Team(
        id: j['id'] as int,
        name: j['name'] as String,
        joinCode: j['join_code'] as String?,
        // The team-list endpoint omits players; default to an empty roster.
        players: (j['players'] as List<dynamic>? ?? const [])
            .map((p) => Player.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
