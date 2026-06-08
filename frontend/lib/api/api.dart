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
import '../models/import_review.dart';

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

  // ── Teams ───────────────────────────────────────────────────────────────

  /// List the current user's teams (id + name only, no roster).
  Future<List<Team>> listTeams() async {
    final res = await _dio.get<List<dynamic>>('/api/teams');
    return res.data!
        .map((item) => Team.fromJson(Map<String, dynamic>.from(item as Map)))
        .toList();
  }

  /// Create a new (empty) team by name.
  Future<Team> createTeam(String name) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/teams',
      data: {'name': name},
    );
    return Team.fromJson(res.data!);
  }

  // ── Roster ──────────────────────────────────────────────────────────────

  /// Upload a team photo and extract player names via AI. When [teamId] is
  /// given the players are appended to that team; otherwise a new team is made.
  Future<ExtractRosterResult> extractRoster(
    XFile image, {
    String? teamName,
    int? teamId,
  }) async {
    final bytes = await image.readAsBytes();
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(
        bytes,
        filename: image.name,
      ),
      if (teamName != null) 'team_name': teamName,
      if (teamId != null) 'team_id': teamId,
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

  /// Remove a single player from a team's roster.
  Future<void> deletePlayer(int teamId, int playerId) async {
    await _dio.delete('/api/teams/$teamId/players/$playerId');
  }

  // ── Roster import review ──────────────────────────────────────────────────

  /// Upload a team photo and stage a review (nothing is saved until confirm).
  Future<ImportReview> createImport(int teamId, XFile image) async {
    final bytes = await image.readAsBytes();
    final formData = FormData.fromMap({
      'image': MultipartFile.fromBytes(bytes, filename: image.name),
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/teams/$teamId/imports',
      data: formData,
    );
    return ImportReview.fromJson(res.data!);
  }

  /// Speak/describe players to add; audio is transcribed and the extracted
  /// players are staged for review (nothing is saved until confirm).
  Future<ImportReview> createImportFromVoice(int teamId, XFile audio) async {
    final bytes = await audio.readAsBytes();
    final formData = FormData.fromMap({
      'audio': MultipartFile.fromBytes(
        bytes,
        filename: audio.name,
        contentType: MediaType.parse(audio.mimeType ?? 'audio/mpeg'),
      ),
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/teams/$teamId/imports/voice',
      data: formData,
    );
    return ImportReview.fromJson(res.data!);
  }

  /// Re-fetch the current review state.
  Future<ImportReview> getImport(int sessionId) async {
    final res = await _dio.get<Map<String, dynamic>>('/api/imports/$sessionId');
    return ImportReview.fromJson(res.data!);
  }

  /// Edit one item's fields (temporary session only).
  Future<ImportReview> editImportItem(
    int sessionId,
    int itemId, {
    String? name,
    int? number,
    String? preferredPosition,
  }) async {
    final res = await _dio.patch<Map<String, dynamic>>(
      '/api/imports/$sessionId/items/$itemId',
      data: {
        if (name != null) 'name': name,
        if (number != null) 'number': number,
        if (preferredPosition != null) 'preferred_position': preferredPosition,
      },
    );
    return ImportReview.fromJson(res.data!);
  }

  /// Remove one item from the import.
  Future<ImportReview> deleteImportItem(int sessionId, int itemId) async {
    final res = await _dio.delete<Map<String, dynamic>>(
      '/api/imports/$sessionId/items/$itemId',
    );
    return ImportReview.fromJson(res.data!);
  }

  /// Merge an item into an existing player (or another import item).
  Future<ImportReview> mergeImportItem(
    int sessionId,
    int itemId, {
    int? targetPlayerId,
    int? targetItemId,
  }) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/imports/$sessionId/items/$itemId/merge',
      data: {
        if (targetPlayerId != null) 'target_player_id': targetPlayerId,
        if (targetItemId != null) 'target_item_id': targetItemId,
      },
    );
    return ImportReview.fromJson(res.data!);
  }

  /// Apply a natural-language command to the review (e.g. "delete Zhao Liu").
  Future<ImportReview> sendImportCommand(int sessionId, String text) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/imports/$sessionId/command',
      data: {'text': text},
    );
    return ImportReview.fromJson(res.data!);
  }

  /// Apply a spoken command (audio is transcribed, then parsed).
  Future<ImportReview> sendImportVoiceCommand(
    int sessionId,
    XFile audio,
  ) async {
    final bytes = await audio.readAsBytes();
    final formData = FormData.fromMap({
      'audio': MultipartFile.fromBytes(
        bytes,
        filename: audio.name,
        contentType: MediaType.parse(audio.mimeType ?? 'audio/mpeg'),
      ),
    });
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/imports/$sessionId/command/voice',
      data: formData,
    );
    return ImportReview.fromJson(res.data!);
  }

  /// Confirm the import — writes the staged players to the database.
  Future<ImportConfirm> confirmImport(int sessionId) async {
    final res = await _dio.post<Map<String, dynamic>>(
      '/api/imports/$sessionId/confirm',
    );
    return ImportConfirm.fromJson(res.data!);
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

  /// Fetch matches, ordered by match date descending. When [teamId] is given,
  /// only that team's matches are returned.
  Future<List<Match>> listMatches({int? teamId}) async {
    final res = await _dio.get<List<dynamic>>(
      '/api/matches',
      queryParameters: {if (teamId != null) 'team_id': teamId},
    );
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
