import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_coach/main.dart';
import 'package:whisper_coach/theme.dart';

void main() {
  group('HomeScreen smoke', () {
    testWidgets('app boots without exceptions', (tester) async {
      await tester.pumpWidget(const WhisperCoachApp());
      await tester.pump();
      expect(find.text('New match'), findsOneWidget);
    });

    testWidgets('Generate lineup button is visible', (tester) async {
      await tester.pumpWidget(const WhisperCoachApp());
      await tester.pump();
      expect(find.text('Generate lineup'), findsOneWidget);
    });

    testWidgets('Upload zone is visible', (tester) async {
      await tester.pumpWidget(const WhisperCoachApp());
      await tester.pump();
      expect(find.text('Upload team roster photo'), findsOneWidget);
    });
  });
}
