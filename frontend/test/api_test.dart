import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:whisper_coach/api/api.dart';
import 'package:whisper_coach/models/player.dart';
import 'package:whisper_coach/models/match.dart';
import 'package:whisper_coach/models/lineup.dart';
import 'package:whisper_coach/models/suggestion.dart';
import 'package:whisper_coach/models/summary.dart';

// ── Sample payloads (copied from the backend contract) ───────────────────────

const _rosterPayload = {
  'team_id': 1,
  'players': [
    {'id': 1, 'name': 'M. Chen', 'number': 10, 'preferred_position': 'CM'},
    {'id': 2, 'name': 'J. Park', 'number': null, 'preferred_position': null},
  ],
};

const _matchPayload = {
  'id': 42,
  'team_id': 1,
  'opponent': 'FC Riverside',
  'location': 'Home',
  'date': '2026-06-07',
  'notes': null,
  'strength': null,
};

const _lineupPayload = {
  'formation': '4-3-3',
  'lineup': [
    {'player': 'H. Yost', 'position': 'GK'},
    {'player': 'G. Lima', 'position': 'LB'},
  ],
  'reason': '4-3-3 gives numerical edge in central midfield.',
};

final _matchDetailsPayload = {
  ..._matchPayload,
  'notes': [
    {
      'id': 1,
      'kind': 'text',
      'content': 'Player has an injury.',
      'ai_response': {
        'substitutions': <dynamic>[],
        'position_changes': <dynamic>[],
        'reason': 'Keep the shape.',
      },
    },
  ],
  'lineup': _lineupPayload,
};

const _notePayload = {
  'note_id': 5,
  'suggestion': {
    'substitutions': [
      {'out': 'A. Diallo', 'in': 'D. Kowalski'}
    ],
    'position_changes': [],
    'reason': 'Fresh legs in midfield.',
  },
};

const _voicePayload = {
  'transcription': 'Left wing is exposed.',
  'suggestion': {
    'substitutions': [],
    'position_changes': [
      {'player': 'G. Lima', 'to': 'LM'}
    ],
    'reason': 'Drop Lima to track the runner.',
  },
};

const _summaryPayload = {
  'summary': 'Solid defensive performance. Won 2–1.',
  'player_performance': [
    {'player': 'M. Chen', 'rating': '8', 'comment': 'Controlled midfield.'},
  ],
  'improvements': ['Press higher in the second half.'],
};

// ── Model round-trip tests ────────────────────────────────────────────────────

void main() {
  group('Model deserialization', () {
    test('Player.fromJson round-trips', () {
      final p = Player.fromJson({
        'id': 1,
        'name': 'M. Chen',
        'number': 10,
        'preferred_position': 'CM',
      });
      expect(p.id, 1);
      expect(p.name, 'M. Chen');
      expect(p.number, 10);
      expect(p.preferredPosition, 'CM');
      expect(p.toJson()['preferred_position'], 'CM');
    });

    test('Player.fromJson handles nulls', () {
      final p = Player.fromJson({'name': 'J. Park'});
      expect(p.id, isNull);
      expect(p.number, isNull);
      expect(p.preferredPosition, isNull);
    });

    test('Match.fromJson round-trips', () {
      final m = Match.fromJson(_matchPayload);
      expect(m.id, 42);
      expect(m.opponent, 'FC Riverside');
      expect(m.teamId, 1);
    });

    test('Lineup.fromJson parses formation and slots', () {
      final l = Lineup.fromJson(_lineupPayload);
      expect(l.formation, '4-3-3');
      expect(l.lineup.length, 2);
      expect(l.lineup[0].player, 'H. Yost');
      expect(l.lineup[0].position, 'GK');
      expect(l.reason, isNotEmpty);
    });

    test('Suggestion.fromJson parses substitutions and position changes', () {
      final s = Suggestion.fromJson(_notePayload['suggestion']!
          as Map<String, dynamic>);
      expect(s.substitutions.length, 1);
      expect(s.substitutions[0].out, 'A. Diallo');
      expect(s.substitutions[0].inPlayer, 'D. Kowalski');
      expect(s.positionChanges, isEmpty);
    });

    test('VoiceNote.fromJson parses transcription and suggestion', () {
      final vn = VoiceNote.fromJson(_voicePayload);
      expect(vn.transcription, 'Left wing is exposed.');
      expect(vn.suggestion.positionChanges.length, 1);
      expect(vn.suggestion.positionChanges[0].player, 'G. Lima');
    });

    test('Summary.fromJson parses all fields', () {
      final s = Summary.fromJson(_summaryPayload);
      expect(s.summary, contains('2–1'));
      expect(s.playerPerformance.length, 1);
      expect(s.improvements.length, 1);
    });
  });

  // ── API client tests ──────────────────────────────────────────────────────

  group('Api client (mocked)', () {
    late Dio dio;
    late DioAdapter adapter;
    late Api apiClient;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
      adapter = DioAdapter(dio: dio);
      apiClient = Api(dio);
    });

    test('createMatch sends correct body and parses response', () async {
      adapter.onPost('/api/matches', (server) {
        return server.reply(201, _matchPayload);
      });
      final m = await apiClient.createMatch(
        teamId: 1,
        opponent: 'FC Riverside',
        location: 'Home',
        date: '2026-06-07',
      );
      expect(m.id, 42);
      expect(m.opponent, 'FC Riverside');
    });

    test('listMatches hits collection path and parses response', () async {
      adapter.onGet('/api/matches', (server) {
        return server.reply(200, [_matchPayload]);
      });
      final matches = await apiClient.listMatches();
      expect(matches, hasLength(1));
      expect(matches.single.opponent, 'FC Riverside');
    });

    test('getMatch parses the saved lineup', () async {
      adapter.onGet('/api/matches/42', (server) {
        return server.reply(200, _matchDetailsPayload);
      });
      final details = await apiClient.getMatch(42);
      expect(details.match.id, 42);
      expect(details.match.notes, isNull);
      expect(details.lineup?.formation, '4-3-3');
    });

    test('generateLineup hits correct path and parses response', () async {
      adapter.onPost('/api/matches/42/lineup', (server) {
        return server.reply(200, _lineupPayload);
      });
      final l = await apiClient.generateLineup(42);
      expect(l.formation, '4-3-3');
      expect(l.lineup.length, 2);
    });

    test('sendNote sends kind=text and returns suggestion', () async {
      adapter.onPost('/api/matches/42/notes', (server) {
        return server.reply(200, _notePayload);
      });
      final resp = await apiClient.sendNote(42, 'Player is tired.');
      expect(resp.noteId, 5);
      expect(resp.suggestion.substitutions.length, 1);
    });

    test('getSummary hits correct path and parses summary', () async {
      adapter.onPost('/api/matches/42/summary', (server) {
        return server.reply(200, _summaryPayload);
      });
      final s = await apiClient.getSummary(42);
      expect(s.summary, isNotEmpty);
      expect(s.playerPerformance, isNotEmpty);
    });

    test('error with FastAPI detail is surfaced', () async {
      adapter.onPost('/api/matches', (server) {
        return server.reply(422, {'detail': 'team_id not found'});
      });
      expect(
        () => apiClient.createMatch(
          teamId: 999,
          opponent: 'X',
          location: 'Y',
          date: '2026-06-07',
        ),
        throwsA(isA<DioException>()),
      );
    });
  });
}
