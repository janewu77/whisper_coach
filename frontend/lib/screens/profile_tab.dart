import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../api/api.dart';
import '../api/client.dart';
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
        final teams = TeamService.instance.teams;
        final currentId = TeamService.instance.currentTeamId;
        return Scaffold(
          backgroundColor: kSurfacePage,
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _userCard(name),
              if (teams.isNotEmpty) ...[
                const SizedBox(height: 20),
                const Text('MY TEAMS', style: kStyleLabel),
                const SizedBox(height: 6),
                Text(
                  'Share a team by giving its code to another coach (they tap '
                  'the team selector → "Join team…").',
                  style: kStyleSecondary,
                ),
                const SizedBox(height: 10),
                for (final t in teams) ...[
                  _TeamCard(team: t, isCurrent: t.id == currentId),
                  const SizedBox(height: 8),
                ],
              ],
              const SizedBox(height: 12),
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

/// One team in the Profile "My teams" list: name, shareable join code, and the
/// members who already share it.
class _TeamCard extends StatefulWidget {
  final Team team;
  final bool isCurrent;

  const _TeamCard({required this.team, required this.isCurrent});

  @override
  State<_TeamCard> createState() => _TeamCardState();
}

class _TeamCardState extends State<_TeamCard> {
  late Future<List<TeamMember>> _members;

  @override
  void initState() {
    super.initState();
    _members = api.getTeamMembers(widget.team.id);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.team;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceCard,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(
          color: widget.isCurrent ? kBrandBorder : kBorderHairline,
          width: widget.isCurrent ? 1 : 0.5,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  t.name,
                  style: kStyleBody.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              if (widget.isCurrent)
                Container(
                  margin: const EdgeInsets.only(left: 6),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: kBrandSubtle,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: const Text('Current',
                      style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: kTextBrand)),
                ),
            ],
          ),
          if (t.joinCode != null) ...[
            const SizedBox(height: 4),
            Row(
              children: [
                Text('Code: ${t.joinCode}', style: kStyleSecondary),
                const SizedBox(width: 4),
                InkWell(
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: t.joinCode!));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Join code copied')),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(100),
                  child: const Padding(
                    padding: EdgeInsets.all(4),
                    child: Icon(Icons.copy, size: 14, color: kTextBrand),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          const Text('SHARED WITH', style: kStyleLabel),
          const SizedBox(height: 6),
          FutureBuilder<List<TeamMember>>(
            future: _members,
            builder: (context, snap) {
              if (snap.connectionState == ConnectionState.waiting) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: SizedBox(
                    width: 16,
                    height: 16,
                    child:
                        CircularProgressIndicator(color: kBrand, strokeWidth: 2),
                  ),
                );
              }
              if (snap.hasError) {
                return Text(dioErrorMessage(snap.error!),
                    style: kStyleSecondary.copyWith(color: kRedFg));
              }
              final members = snap.data ?? const [];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final m in members)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(Icons.person_outline,
                              size: 15, color: kTextTertiary),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(m.label,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: kStyleBodyMd),
                          ),
                        ],
                      ),
                    ),
                  if (members.length <= 1)
                    Text('Only you — share the code to add coaches.',
                        style: kStyleSecondary.copyWith(color: kTextTertiary)),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
