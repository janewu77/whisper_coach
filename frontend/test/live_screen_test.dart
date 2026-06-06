import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_coach/main.dart';
import 'package:whisper_coach/screens/live_screen.dart';
import 'package:whisper_coach/theme.dart';

void main() {
  Widget buildScreen() {
    return MaterialApp(
      theme: buildTheme(),
      home: const LiveScreen(
        args: LiveScreenArgs(matchId: 1, opponent: 'FC Test'),
      ),
    );
  }

  testWidgets('defaults to prominent voice input', (tester) async {
    await tester.pumpWidget(buildScreen());

    expect(find.byKey(const Key('voice-record-button')), findsOneWidget);
    expect(find.text('Tap to speak'), findsOneWidget);
    expect(find.byKey(const Key('live-note-text-field')), findsNothing);

    final recordButton = tester.getSize(
      find.byKey(const Key('voice-record-button')),
    );
    expect(recordButton, const Size(104, 104));

    final switchButton = tester.getSize(
      find.byKey(const Key('text-input-mode-button')),
    );
    expect(switchButton.height, 44);
  });

  testWidgets('can switch from voice input to text input', (tester) async {
    await tester.pumpWidget(buildScreen());

    await tester.tap(find.byKey(const Key('text-input-mode-button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('live-note-text-field')), findsOneWidget);
    expect(find.byKey(const Key('send-text-note-button')), findsOneWidget);
    expect(find.byKey(const Key('voice-record-button')), findsNothing);
  });
}
