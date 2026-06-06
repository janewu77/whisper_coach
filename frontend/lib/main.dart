import 'package:flutter/material.dart';
import 'theme.dart';
import 'screens/home_screen.dart';
import 'screens/match_list_screen.dart';
import 'screens/pitch_screen.dart';
import 'screens/live_screen.dart';
import 'models/lineup.dart';

void main() {
  runApp(const WhisperCoachApp());
}

class WhisperCoachApp extends StatelessWidget {
  const WhisperCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Whisper Coach',
      theme: buildTheme(),
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => const MatchListScreen(),
            );
          case '/new':
            return MaterialPageRoute(
              builder: (_) => const HomeScreen(),
            );
          case '/pitch':
            final args = settings.arguments as PitchScreenArgs;
            return MaterialPageRoute(
              builder: (_) => PitchScreen(args: args),
            );
          case '/live':
            final args = settings.arguments as LiveScreenArgs;
            return MaterialPageRoute(
              builder: (_) => LiveScreen(args: args),
            );
          default:
            return null;
        }
      },
    );
  }
}

// ── Route argument types ─────────────────────────────────────────────────────

class PitchScreenArgs {
  final int matchId;
  final String opponent;
  final Lineup lineup;
  final String? strength;

  const PitchScreenArgs({
    required this.matchId,
    required this.opponent,
    required this.lineup,
    this.strength,
  });
}

class LiveScreenArgs {
  final int matchId;
  final String opponent;

  const LiveScreenArgs({required this.matchId, required this.opponent});
}
