import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:whisper_coach/api/api.dart';
import 'package:whisper_coach/models/match.dart';
import 'package:whisper_coach/screens/match_list_screen.dart';
import 'package:whisper_coach/theme.dart';

void main() {
  group('MatchListScreen', () {
    late Dio dio;
    late DioAdapter adapter;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
      adapter = DioAdapter(dio: dio);
    });

    testWidgets('shows the empty state and create action', (tester) async {
      adapter.onGet('/api/matches', (server) => server.reply(200, []));

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: MatchListScreen(apiClient: Api(dio)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Matches'), findsOneWidget);
      expect(find.text('No matches yet'), findsOneWidget);
      expect(find.text('New match'), findsOneWidget);
    });

    testWidgets('renders matches returned by the API', (tester) async {
      adapter.onGet('/api/matches', (server) {
        return server.reply(200, [
          {
            'id': 42,
            'team_id': 1,
            'opponent': 'FC Riverside',
            'location': 'Home',
            'date': '2026-06-07',
            'notes': null,
            'strength': 'strong',
          },
        ]);
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: MatchListScreen(apiClient: Api(dio)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('vs FC Riverside'), findsOneWidget);
      expect(find.text('Strong opponent'), findsOneWidget);
    });

    testWidgets('refreshes matches without returning a Future from setState',
        (tester) async {
      final api = _SequenceApi();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: MatchListScreen(apiClient: api),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byTooltip('Refresh matches'));
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('vs Updated FC'), findsOneWidget);
    });
  });
}

class _SequenceApi extends Api {
  int requestCount = 0;

  @override
  Future<List<Match>> listMatches() async {
    requestCount++;
    return [
      Match(
        id: requestCount,
        teamId: 1,
        opponent: requestCount == 1 ? 'First FC' : 'Updated FC',
        location: 'Home',
        date: '2026-06-07',
      ),
    ];
  }
}
