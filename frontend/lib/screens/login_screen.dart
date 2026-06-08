import 'package:flutter/material.dart';

import '../auth/auth_service.dart';
import '../theme.dart';

/// Shown when login is enabled and the user is not authenticated.
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
    if (mounted) setState(() => _busy = false);
  }

  @override
  Widget build(BuildContext context) {
    final error = AuthService.instance.error;
    return Scaffold(
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/images/whisper_coach_logo.png',
                width: 72,
                height: 72,
              ),
              const SizedBox(height: 20),
              Text('Whisper Coach', style: kStyleScreenTitle),
              const SizedBox(height: 6),
              Text(
                'Sign in to manage your matches.',
                textAlign: TextAlign.center,
                style: kStyleSecondary,
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 220,
                child: ElevatedButton.icon(
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
              ),
              if (error != null) ...[
                const SizedBox(height: 16),
                Text(
                  error,
                  textAlign: TextAlign.center,
                  style: kStyleSecondary.copyWith(color: Colors.redAccent),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
