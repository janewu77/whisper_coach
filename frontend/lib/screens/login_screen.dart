import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../theme.dart';

/// Start / landing page shown by the AuthGate when no user is signed in.
/// Presents the product and a single "Log in / Sign up" action (Auth0).
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _busy = false;

  Future<void> _login() async {
    setState(() => _busy = true);
    await AuthService.instance.login();
    // On web this redirects away; on native we return here once done.
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final error = AuthService.instance.error;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ── Brand ──────────────────────────────────────────────
                Container(
                  width: 88,
                  height: 88,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: kBrandSubtle,
                    borderRadius: BorderRadius.circular(kRadiusSheet),
                  ),
                  child: Image.asset(
                    'assets/images/whisper_coach_logo.png',
                    width: 56,
                    height: 56,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'Whisper Coach',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.w600,
                    color: kTextPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Whisper your tactics — AI does the rest.',
                  textAlign: TextAlign.center,
                  style: kStyleBody.copyWith(color: kTextSecondary),
                ),

                // ── Feature highlights ─────────────────────────────────
                const SizedBox(height: 28),
                const _Feature(
                  icon: Icons.groups_2_outlined,
                  title: 'Roster from a photo',
                  subtitle: 'Snap your team sheet — AI builds the squad.',
                ),
                const SizedBox(height: 14),
                const _Feature(
                  icon: Icons.grid_view_outlined,
                  title: 'Instant AI lineup',
                  subtitle: 'Formation and starting XI vs. any opponent.',
                ),
                const SizedBox(height: 14),
                const _Feature(
                  icon: Icons.mic_none_outlined,
                  title: 'Live touchline suggestions',
                  subtitle: 'Speak a note, get a tactical adjustment.',
                ),

                // ── Login ──────────────────────────────────────────────
                const SizedBox(height: 32),
                ElevatedButton.icon(
                  onPressed: _busy ? null : _login,
                  icon: _busy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kTextOnBrand,
                          ),
                        )
                      : const Icon(Icons.login, size: 20),
                  label: Text(_busy ? 'Signing in…' : 'Log in / Sign up'),
                ),
                const SizedBox(height: 12),
                Text(
                  'Secure sign-in powered by Auth0.',
                  textAlign: TextAlign.center,
                  style: kStyleSecondary.copyWith(color: kTextTertiary),
                ),
                if (error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: kRedBg,
                      borderRadius: BorderRadius.circular(kRadiusInput),
                    ),
                    child: Text(
                      error,
                      textAlign: TextAlign.center,
                      style: kStyleSecondary.copyWith(color: kRedFg),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Feature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _Feature({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: kBrandSubtle,
            borderRadius: BorderRadius.circular(kRadiusInput),
          ),
          child: Icon(icon, color: kTextBrand, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: kStyleBody.copyWith(fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(subtitle, style: kStyleSecondary),
            ],
          ),
        ),
      ],
    );
  }
}
