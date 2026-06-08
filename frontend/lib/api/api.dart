import 'package:dio/dio.dart';
import 'package:http_parser/http_parser.dart';
import 'package:image_picker/image_picker.dart';
import 'client.dart' as wc_client;
import '../models/player.dart';
import '../models/team.dart';
import '../models/match.dart';
import '../models/lineup.dart';
import '../models/suggestion.dart';
import '../models/summary.dart';

class ExtractRosterResult {
  final int teamId;
  final List<Player> players;

  const ExtractRosterResult({required this.teamId, required this.players});
}

class Api {
  final Dio _dio;

  Api([Dio? dio]) : _dio = dio ?? wc_client.dio;

  // ── Auth ──────────────────────────────────────────────────────────────────

  /// The current authenticated user. Also a cheap way to verify the token is
  /// accepted by the backend (401/503 otherwise).
  Future<Map<String, dynamic>> getMe() async {
    final res = await _dio.get<Map<String, dynamic>>('/api/me');
    return res.data!;
  }

  // ── Roster ──────────────────────────────────────────────────────────────

  /// Upload a team photo and extract player names via AI.
  Future<ExtractRosterResult> extractRoster(
    XFile image, {
    String? teamName,
  }) async {
    final bytes = await image.readAsBytes();
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        bytes,
        filename: image.name,
      ),
      if (teamName != null) 'team_name': teamName,
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/roster/extract',
      data: formData,
    );
    final data = res.data!;
    return ExtractRosterResult(
      teamId: data['team_id'] as int,
      players: (data['players'] as List<dynamic>)
          .map((p) => Player.fromJson(p as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Fetch a team with its players.
  Future<Team> getTeam(int teamId) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/teams/$teamId');
    return Team.fromJson(res.data!);
  }

  // ── Matches ──────────────────────────────────────────────────────────────

  /// Create a new match. Returns the created match.
  Future<Match> createMatch({
    required int teamId,
    required String opponent,
    required String location,
    required String date,
    String? notes,
    String? strength,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/matches',
      data: {
        'team_id': teamId,
        'opponent': opponent,
        'location': location,
        'date': date,
        if (notes != null && notes.isNotEmpty) 'notes': notes,
        if (strength != null) 'strength': strength,
      },
    );
    return Match.fromJson(res.data!);
  }

  /// Fetch a match (includes latest lineup and notes).
  Future<MatchDetails> getMatch(int matchId) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/matches/$matchId');
    return MatchDetails.fromJson(res.data!);
  }

  /// Fetch all matches, ordered by match date descending.
  Future<List<Match>> listMatches() async {
    final res = await _dio.get<List<dynamic>>('/api/matches');
    return res.data!
        .map(
          (item) => Match.fromJson(
            Map<String, dynamic>.from(item as Map),
          ),
        )
        .toList();
  }

  // ── Lineup ───────────────────────────────────────────────────────────────

  /// Generate (or regenerate) a lineup for a match.
  Future<Lineup> generateLineup(int matchId, {String? strength}) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/matches/$matchId/lineup',
      data: {
        if (strength != null) 'strength': strength,
      },
    );
    return Lineup.fromJson(res.data!);
  }

  // ── Notes (in-match) ─────────────────────────────────────────────────────

  /// Send a text note and get a tactical suggestion.
  Future<NoteResponse> sendNote(int matchId, String content) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/matches/$matchId/notes',
      data: {'kind': 'text', 'content': content},
    );
    return NoteResponse.fromJson(res.data!);
  }

  /// Upload a voice note audio file. Returns transcription + suggestion.
  Future<VoiceNote> sendVoiceNote(int matchId, XFile audio) async {
    final bytes = await audio.readAsBytes();
    final formData = FormData.fromMap({
      'audio': MultipartFile.fromBytes(
        bytes,
        filename: audio.name,
        contentType: MediaType.parse(audio.mimeType ?? 'audio/mpeg'),
      ),
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/matches/$matchId/notes/voice',
      data: formData,
    );
    return VoiceNote.fromJson(res.data!);
  }

  // ── Summary ──────────────────────────────────────────────────────────────

  /// Generate a post-match summary with player ratings and improvements.
  Future<Summary> getSummary(int matchId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/matches/$matchId/summary',
    );
    return Summary.fromJson(res.data!);
  }
}

// Module-level getter so callers can do `import 'api.dart'; api.extractRoster(…)`
final Api api = Api();
