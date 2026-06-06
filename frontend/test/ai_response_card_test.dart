import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_coach/widgets/ai_response_card.dart';
import 'package:whisper_coach/models/suggestion.dart';
import 'package:whisper_coach/theme.dart';

void main() {
  group('AiResponseCard', () {
    testWidgets('renders reason text', (tester) async {
      final suggestion = Suggestion.fromJson({
        'substitutions': [],
        'position_changes': [],
        'reason': 'Drop Lima 10m deeper.',
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: AiResponseCard(suggestion: suggestion),
            ),
          ),
        ),
      );

      expect(find.text('Drop Lima 10m deeper.'), findsOneWidget);
    });

    testWidgets('renders substitutions', (tester) async {
      final suggestion = Suggestion.fromJson({
        'substitutions': [
          {'out': 'A. Diallo', 'in': 'D. Kowalski'}
        ],
        'position_changes': [],
        'reason': 'Fresh legs.',
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: AiResponseCard(suggestion: suggestion),
            ),
          ),
        ),
      );

      expect(find.textContaining('A. Diallo'), findsOneWidget);
      expect(find.textContaining('D. Kowalski'), findsOneWidget);
    });

    testWidgets('renders position changes', (tester) async {
      final suggestion = Suggestion.fromJson({
        'substitutions': [],
        'position_changes': [
          {'player': 'G. Lima', 'to': 'LM'}
        ],
        'reason': 'Track the runner.',
      });

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(12),
              child: AiResponseCard(suggestion: suggestion),
            ),
          ),
        ),
      );

      expect(find.textContaining('G. Lima'), findsOneWidget);
      expect(find.textContaining('LM'), findsOneWidget);
    });
  });
}
