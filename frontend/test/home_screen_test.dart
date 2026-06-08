import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dio/dio.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:whisper_coach/api/api.dart';
import 'package:whisper_coach/models/match.dart';
import 'package:whisper_coach/screens/matches_tab.dart';
import 'package:whisper_coach/theme.dart';

void main() {
  group('MatchesTab', () {
    late Dio dio;
    late DioAdapter adapter;

    setUp(() {
      dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
      adapter = DioAdapter(dio: dio);
    });

    testWidgets('shows the empty state and create action', (tester) async {
      adapter.onGet(
        '/api/matches',
        (server) => server.reply(200, []),
        queryParameters: {'team_id': 1},
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: MatchesTab(teamId: 1, apiClient: Api(dio)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No matches yet'), findsOneWidget);
      expect(find.text('New match'), findsOneWidget);
    });

    testWidgets('renders matches returned by the API', (tester) async {
      adapter.onGet(
        '/api/matches',
        (server) {
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
        },
        queryParameters: {'team_id': 1},
      );

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: MatchesTab(teamId: 1, apiClient: Api(dio)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('vs FC Riverside'), findsOneWidget);
      expect(find.text('Strong opponent'), findsOneWidget);
    });

    testWidgets('pull-to-refresh reloads without throwing', (tester) async {
      final api = _SequenceApi();

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: MatchesTab(teamId: 1, apiClient: api),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('vs First FC'), findsOneWidget);

      // Drag down to trigger the RefreshIndicator.
      await tester.fling(
        find.text('vs First FC'),
        const Offset(0, 350),
        1000,
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('vs Updated FC'), findsOneWidget);
    });
  });
}

class _SequenceApi extends Api {
  int requestCount = 0;

  @override
  Future<List<Match>> listMatches({int? teamId}) async {
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
