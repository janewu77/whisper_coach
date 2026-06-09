/// An unavailability period for a player (injury or vacation). `from`/`to` are
/// inclusive calendar dates.
class Absence {
  final String kind; // 'injury' | 'vacation'
  final DateTime from;
  final DateTime to;
  final String? note;

  const Absence({
    required this.kind,
    required this.from,
    required this.to,
    this.note,
  });

  factory Absence.fromJson(Map<String, dynamic> j) => Absence(
        kind: j['kind'] as String,
        from: DateTime.parse(j['from'] as String),
        to: DateTime.parse(j['to'] as String),
        note: j['note'] as String?,
      );

  static String _fmt(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Map<String, dynamic> toJson() => {
        'kind': kind,
        'from': _fmt(from),
        'to': _fmt(to),
        if (note != null && note!.isNotEmpty) 'note': note,
      };
}

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
  final List<Absence> absences;

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
    this.absences = const [],
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
        absences: (j['absences'] as List<dynamic>? ?? const [])
            .map((e) => Absence.fromJson(e as Map<String, dynamic>))
            .toList(),
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
        'absences': absences.map((a) => a.toJson()).toList(),
      };

  // ── Availability ─────────────────────────────────────────────────────────

  /// The absence covering [day] (latest-ending if several), or null if free.
  Absence? activeAbsence(DateTime day) {
    final d = DateTime(day.year, day.month, day.day);
    Absence? active;
    for (final a in absences) {
      final f = DateTime(a.from.year, a.from.month, a.from.day);
      final t = DateTime(a.to.year, a.to.month, a.to.day);
      if (!d.isBefore(f) && !d.isAfter(t)) {
        if (active == null || t.isAfter(active.to)) active = a;
      }
    }
    return active;
  }

  bool availableOn(DateTime day) => activeAbsence(day) == null;
}
