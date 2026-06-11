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

  testWidgets('composer shows big voice button AND keyboard input together',
      (tester) async {
    await tester.pumpWidget(buildScreen());

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

    // End match lives in the app bar.
    expect(find.text('End match'), findsOneWidget);
  });
}
