import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http_mock_adapter/http_mock_adapter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:whisper_coach/api/api.dart';
import 'package:whisper_coach/main.dart';
import 'package:whisper_coach/screens/live_screen.dart';
import 'package:whisper_coach/theme.dart';

void main() {
  late Api mockApi;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    final dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));
    final adapter = DioAdapter(dio: dio);
    adapter.onGet('/api/matches/1', (server) {
      return server.reply(200, {
        'id': 1,
        'team_id': 1,
        'opponent': 'FC Test',
        'location': '',
        'date': '2026-06-11',
        'notes': <dynamic>[],
        'lineup': null,
      });
    });
    mockApi = Api(dio);
  });

  Widget buildScreen() {
    return MaterialApp(
      theme: buildTheme(),
      home: LiveScreen(
        args: const LiveScreenArgs(matchId: 1, opponent: 'FC Test'),
        apiClient: mockApi,
      ),
    );
  }

  testWidgets('composer shows big voice button AND keyboard input together',
      (tester) async {
    await tester.pumpWidget(buildScreen());
    // Let the history/clock restore settle (dio chains zero-duration timers,
    // each firing on its own pump).
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }

    // Big voice circle, text field and send button — all visible at once,
    // no mode switching.
    expect(find.byKey(const Key('voice-record-button')), findsOneWidget);
    expect(find.byKey(const Key('live-note-text-field')), findsOneWidget);
    expect(find.byKey(const Key('send-text-note-button')), findsOneWidget);
    final voiceButton =
        tester.getSize(find.byKey(const Key('voice-record-button')));
    expect(voiceButton.width, greaterThanOrEqualTo(80));

    // The old quick actions and mode switcher are gone.
    expect(find.text('Goal'), findsNothing);
    expect(find.text('Injury'), findsNothing);
    expect(find.byKey(const Key('text-input-mode-button')), findsNothing);

    // No start/stop lifecycle — just a Summary action in the app bar.
    expect(find.text('End match'), findsNothing);
    expect(find.text('Summary'), findsOneWidget);

    // Dispose the screen so its periodic timers are cancelled before the
    // framework's pending-timer check.
    await tester.pumpWidget(const SizedBox());
  });
}
