class Player {
  final int? id;
  final String name;
  final int? number;
  final String? preferredPosition;
  // Extended profile (populated by the player detail screen).
  final List<String> positions;
  final String? preferredFoot; // "left" | "right" | "both"
  final int? heightCm;
  final List<String> traits;
  final String? description;

  const Player({
    this.id,
    required this.name,
    this.number,
    this.preferredPosition,
    this.positions = const [],
    this.preferredFoot,
    this.heightCm,
    this.traits = const [],
    this.description,
  });

  factory Player.fromJson(Map<String, dynamic> j) => Player(
        id: j['id'] as int?,
        name: j['name'] as String,
        number: j['number'] as int?,
        preferredPosition: j['preferred_position'] as String?,
        positions: (j['positions'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
        preferredFoot: j['preferred_foot'] as String?,
        heightCm: j['height_cm'] as int?,
        traits: (j['traits'] as List<dynamic>? ?? const [])
            .map((e) => e as String)
            .toList(),
        description: j['description'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        if (number != null) 'number': number,
        if (preferredPosition != null) 'preferred_position': preferredPosition,
        'positions': positions,
        if (preferredFoot != null) 'preferred_foot': preferredFoot,
        if (heightCm != null) 'height_cm': heightCm,
        'traits': traits,
        if (description != null) 'description': description,
      };
}
