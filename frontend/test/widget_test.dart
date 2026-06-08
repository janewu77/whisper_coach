import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:whisper_coach/screens/login_screen.dart';
import 'package:whisper_coach/theme.dart';

void main() {
  testWidgets('login screen renders the brand and sign-in action',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: buildTheme(), home: const LoginScreen()),
    );
    await tester.pump();

    expect(find.text('Whisper Coach'), findsOneWidget);
    expect(find.text('Log in / Sign up'), findsOneWidget);
  });
}
