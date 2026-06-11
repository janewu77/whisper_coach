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

  testWidgets('composer is one input with mic inside and a send button',
      (tester) async {
    await tester.pumpWidget(buildScreen());

    // Single text field with the voice button as its suffix icon.
    expect(find.byKey(const Key('live-note-text-field')), findsOneWidget);
    expect(find.byKey(const Key('voice-record-button')), findsOneWidget);
    expect(find.byKey(const Key('send-text-note-button')), findsOneWidget);

    // The old quick actions and mode switcher are gone.
    expect(find.text('Goal'), findsNothing);
    expect(find.text('Injury'), findsNothing);
    expect(find.text('Tap to speak'), findsNothing);
    expect(find.byKey(const Key('text-input-mode-button')), findsNothing);

    // End match moved into the app bar.
    expect(find.text('End match'), findsOneWidget);
  });
}
