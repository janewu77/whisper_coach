import 'player.dart';

class Team {
  final int id;
  final String name;
  final List<Player> players;

  const Team({required this.id, required this.name, required this.players});

  factory Team.fromJson(Map<String, dynamic> j) => Team(
        id: j['id'] as int,
        name: j['name'] as String,
        players: (j['players'] as List<dynamic>)
            .map((p) => Player.fromJson(p as Map<String, dynamic>))
            .toList(),
      );
}
