import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../auth/auth_service.dart';
import '../config.dart';
import '../models/team.dart';
import '../services/settings_service.dart';
import '../services/team_service.dart';
import '../theme.dart';

/// Profile / settings tab. Currently the speaker language used for voice input.
/// (The app UI itself is English-only — this only affects speech recognition.)
class ProfileTab extends StatelessWidget {
  const ProfileTab({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable:
          Listenable.merge([SettingsService.instance, TeamService.instance]),
      builder: (context, _) {
        final settings = SettingsService.instance;
        final name = AuthService.instance.userName;
        final team = TeamService.instance.current;
        return Scaffold(
          backgroundColor: kSurfacePage,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _userCard(name),
              if (team?.joinCode != null) ...[
                const SizedBox(height: 12),
                _teamCard(context, team!),
              ],
              const SizedBox(height: 20),
              const Text('SPEAKER LANGUAGE', style: kStyleLabel),
              const SizedBox(height: 6),
              Text(
                'The language you speak for voice input (player descriptions, '
                'roster dictation, live notes). Improves speech recognition. '
                'The app interface stays in English.',
                style: kStyleSecondary,
              ),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: kSurfaceCard,
                  borderRadius: BorderRadius.circular(kRadiusCard),
                  border: Border.all(color: kBorderHairline, width: 0.5),
                ),
                clipBehavior: Clip.antiAlias,
                child: Column(
                  children: [
                    for (var i = 0; i < kSpeakerLanguages.length; i++) ...[
                      if (i > 0) const Divider(height: 1),
                      _LangRow(
                        lang: kSpeakerLanguages[i],
                        selected:
                            settings.speakerLanguage == kSpeakerLanguages[i].code,
                        onTap: () => settings
                            .setSpeakerLanguage(kSpeakerLanguages[i].code),
                      ),
                    ],
                  ],
                ),
              ),
              if (Config.authEnabled) ...[
                const SizedBox(height: 24),
                OutlinedButton.icon(
                  onPressed: () => AuthService.instance.logout(),
                  icon: const Icon(Icons.logout_outlined, size: 18),
                  label: const Text('Log out'),
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  /// Current team + its shareable join code (others enter it via "Join team…").
  Widget _teamCard(BuildContext context, Team team) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceCard,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kBorderHairline, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('CURRENT TEAM', style: kStyleLabel),
                const SizedBox(height: 4),
                Text(team.name,
                    style: kStyleBody.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text('Share code: ${team.joinCode}', style: kStyleSecondary),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: () async {
              await Clipboard.setData(ClipboardData(text: team.joinCode!));
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Join code copied')),
                );
              }
            },
            icon: const Icon(Icons.copy, size: 16),
            label: const Text('Copy'),
          ),
        ],
      ),
    );
  }

  Widget _userCard(String? name) {
    final initial = (name == null || name.isEmpty) ? '?' : name[0].toUpperCase();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kSurfaceCard,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kBorderHairline, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: kBrandSubtle,
              shape: BoxShape.circle,
            ),
            child: Text(
              initial,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: kTextBrand,
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name == null || name.isEmpty ? 'Coach' : name,
                  style: kStyleBody.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text('Signed in', style: kStyleSecondary),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _LangRow extends StatelessWidget {
  final SpeakerLanguage lang;
  final bool selected;
  final VoidCallback onTap;

  const _LangRow({
    required this.lang,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(
                lang.label,
                style: kStyleBody.copyWith(
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  color: selected ? kTextBrand : kTextPrimary,
                ),
              ),
            ),
            if (selected) const Icon(Icons.check, size: 18, color: kBrand),
          ],
        ),
      ),
    );
  }
}
