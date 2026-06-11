import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_coach/widgets/pitch_view.dart';
import 'package:whisper_coach/models/lineup.dart';
import 'package:whisper_coach/theme.dart';

List<PitchPlayer> _makePlayers(int n) => List.generate(
      n,
      (i) => PitchPlayer(
        id: '$i',
        initials: 'P$i',
        label: 'Player $i',
        position: 'CM',
        x: 10.0 + i * 8,
        y: 50,
      ),
    );

void main() {
  group('PitchView', () {
    testWidgets('renders N player dots for N players', (tester) async {
      const n = 11;
      final players = _makePlayers(n);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 460,
              child: PitchView(players: players),
            ),
          ),
        ),
      );

      // One GestureDetector per player
      expect(find.byType(GestureDetector), findsNWidgets(n));
    });

    testWidgets('tap calls onTap with correct player', (tester) async {
      PitchPlayer? tapped;
      final players = _makePlayers(3);

      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(),
          home: Scaffold(
            body: SizedBox(
              width: 300,
              height: 460,
              child: PitchView(
                players: players,
                onTap: (p) => tapped = p,
              ),
            ),
          ),
        ),
      );

      // Tap the first GestureDetector (player 0)
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(tapped, isNotNull);
      expect(tapped!.id, '0');
    });

    testWidgets('layoutFromLineup produces correct player count', (_) async {
      final lineup = Lineup.fromJson({
        'formation': '4-3-3',
        'lineup': List.generate(
          11,
          (i) => {'player': 'Player $i', 'position': 'POS'},
        ),
        'reason': 'test',
      });
      final result = layoutFromLineup(lineup);
      expect(result.length, 11);
    });
  });
}
