import 'package:flutter/material.dart';
import 'theme.dart';
import 'auth/auth_service.dart';
import 'services/settings_service.dart';
import 'screens/home_screen.dart';
import 'screens/login_screen.dart';
import 'screens/team_gate.dart';
import 'screens/pitch_screen.dart';
import 'screens/live_screen.dart';
import 'models/lineup.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Restore any existing session (and complete the web login redirect) before
  // the first frame so we don't flash the login screen for signed-in users.
  await AuthService.instance.init();
  await SettingsService.instance.load();
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
              builder: (_) => const AuthGate(),
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

// ── Auth gate ────────────────────────────────────────────────────────────────

/// Routes between the login screen and the app based on auth state. When login
/// is disabled (no Auth0 config) the user is always treated as authenticated,
/// so this transparently shows the team gate.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AuthService.instance,
      builder: (context, _) {
        final auth = AuthService.instance;
        if (!auth.isReady) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: kBrand)),
          );
        }
        return auth.isAuthenticated ? const TeamGate() : const LoginScreen();
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
