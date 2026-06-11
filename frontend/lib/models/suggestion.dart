class Substitution {
  final String out;
  final String inPlayer;

  const Substitution({required this.out, required this.inPlayer});

  factory Substitution.fromJson(Map<String, dynamic> j) => Substitution(
        out: j['out'] as String,
        inPlayer: j['in'] as String,
      );
}

class PositionChange {
  final String player;
  final String to;

  const PositionChange({required this.player, required this.to});

  factory PositionChange.fromJson(Map<String, dynamic> j) => PositionChange(
        player: j['player'] as String,
        to: j['to'] as String,
      );
}

class Suggestion {
  // Whether the AI decided the note needs an on-screen answer. False for
  // pure event logs (goal, card…) — registered silently.
  final bool respond;
  final List<Substitution> substitutions;
  final List<PositionChange> positionChanges;
  final String reason;

  const Suggestion({
    this.respond = true,
    required this.substitutions,
    required this.positionChanges,
    required this.reason,
  });

  factory Suggestion.fromJson(Map<String, dynamic> j) => Suggestion(
        respond: j['respond'] as bool? ?? true,
        substitutions: (j['substitutions'] as List<dynamic>? ?? [])
            .map((s) => Substitution.fromJson(s as Map<String, dynamic>))
            .toList(),
        positionChanges: (j['position_changes'] as List<dynamic>? ?? [])
            .map((p) => PositionChange.fromJson(p as Map<String, dynamic>))
            .toList(),
        reason: j['reason'] as String,
      );
}

class VoiceNote {
  final String transcription;
  final Suggestion suggestion;

  const VoiceNote({required this.transcription, required this.suggestion});

  factory VoiceNote.fromJson(Map<String, dynamic> j) => VoiceNote(
        transcription: j['transcription'] as String,
        suggestion: Suggestion.fromJson(
          j['suggestion'] as Map<String, dynamic>,
        ),
      );
}

class NoteResponse {
  final int noteId;
  final Suggestion suggestion;

  const NoteResponse({required this.noteId, required this.suggestion});

  factory NoteResponse.fromJson(Map<String, dynamic> j) => NoteResponse(
        noteId: j['note_id'] as int,
        suggestion: Suggestion.fromJson(
          j['suggestion'] as Map<String, dynamic>,
        ),
      );
}
