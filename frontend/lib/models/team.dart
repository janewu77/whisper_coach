import 'player.dart';

/// A user who belongs to a team (Profile → team members list).
class TeamMember {
  final String auth0Id;
  final String? name;
  final String? email;

  const TeamMember({required this.auth0Id, this.name, this.email});

  factory TeamMember.fromJson(Map<String, dynamic> j) => TeamMember(
        auth0Id: j['auth0_id'] as String,
        name: j['name'] as String?,
        email: j['email'] as String?,
      );

  /// Best available display label.
  String get label {
    if (name != null && name!.isNotEmpty) return name!;
    if (email != null && email!.isNotEmpty) return email!;
    return auth0Id;
  }
}

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
