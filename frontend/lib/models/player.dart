class Player {
  final int? id;
  final String name;
  final int? number;
  final String? preferredPosition;

  const Player({
    this.id,
    required this.name,
    this.number,
    this.preferredPosition,
  });

  factory Player.fromJson(Map<String, dynamic> j) => Player(
        id: j['id'] as int?,
        name: j['name'] as String,
        number: j['number'] as int?,
        preferredPosition: j['preferred_position'] as String?,
      );

  Map<String, dynamic> toJson() => {
        if (id != null) 'id': id,
        'name': name,
        if (number != null) 'number': number,
        if (preferredPosition != null) 'preferred_position': preferredPosition,
      };
}
