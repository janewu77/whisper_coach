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
      listenable: Listenable.merge([
        SettingsService.instance,
        TeamService.instance,
        AuthService.instance,
      ]),
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
              _userCard(context, name, AuthService.instance.userEmail),
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
              DropdownButtonFormField<String>(
                value: settings.speakerLanguage,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Speaker language'),
                items: [
                  for (final l in kSpeakerLanguages)
                    DropdownMenuItem(value: l.code, child: Text(l.label)),
                ],
                onChanged: (code) {
                  if (code != null) settings.setSpeakerLanguage(code);
                },
              ),
              const SizedBox(height: 20),
              const _ReportStyleSection(),
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

  Widget _userCard(BuildContext context, String? name, String? email) {
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
                Text(
                  email == null || email.isEmpty ? 'Signed in' : email,
                  style: kStyleSecondary,
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Edit name',
            onPressed: () => _editName(context, name),
            icon: const Icon(Icons.edit_outlined, size: 18, color: kTextSecondary),
          ),
        ],
      ),
    );
  }

  Future<void> _editName(BuildContext context, String? current) async {
    final ctrl = TextEditingController(text: current ?? '');
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Your name'),
        content: TextField(
          controller: ctrl,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Name'),
          onSubmitted: (v) => Navigator.pop(ctx, v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, ctrl.text),
            child: const Text('Save'),
          ),
        ],
      ),
    );
    final trimmed = name?.trim() ?? '';
    if (trimmed.isEmpty || trimmed == (current ?? '')) return;
    try {
      final updated = await api.updateMe(name: trimmed);
      AuthService.instance.setUserName((updated['name'] as String?) ?? trimmed);
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
      }
    }
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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _members = api.getTeamMembers(widget.team.id);
  }

  Future<void> _refreshCode() async {
    setState(() => _busy = true);
    try {
      await TeamService.instance.refreshCode(widget.team.id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('New join code generated')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteTeam() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Delete "${widget.team.name}"?'),
        content: const Text(
          'This permanently removes the team and all its players, matches, '
          'lineups and notes for everyone. This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: TextButton.styleFrom(foregroundColor: kRedFg),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busy = true);
    try {
      await TeamService.instance.deleteTeam(widget.team.id);
      // The card is removed from the tree by the parent rebuild.
    } catch (e) {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
      }
    }
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
          // Only the owner sees / manages the join code (backend hides it from
          // other members — joinCode is null for them).
          if (t.isOwner && t.joinCode != null) ...[
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
                InkWell(
                  onTap: _busy ? null : _refreshCode,
                  borderRadius: BorderRadius.circular(100),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: _busy
                        ? const SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                                color: kBrand, strokeWidth: 2),
                          )
                        : const Icon(Icons.refresh, size: 14, color: kTextBrand),
                  ),
                ),
              ],
            ),
            Text('Refresh to invalidate the old code.',
                style: kStyleSecondary.copyWith(color: kTextTertiary)),
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
                  if (members.isEmpty)
                    Text('Just you — share the code to add coaches.',
                        style: kStyleSecondary.copyWith(color: kTextTertiary)),
                ],
              );
            },
          ),
          // Only the owner can delete the whole team.
          if (t.isOwner) ...[
            const SizedBox(height: 10),
            const Divider(height: 1, color: kBorderHairline),
            const SizedBox(height: 4),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: _busy ? null : _deleteTeam,
                style: TextButton.styleFrom(
                  foregroundColor: kRedFg,
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                ),
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('Delete team'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Personal report style: paste example texts (old summaries, someone's
/// speeches), distill them into a style card, and every AI match summary is
/// written in that voice.
class _ReportStyleSection extends StatefulWidget {
  const _ReportStyleSection();

  @override
  State<_ReportStyleSection> createState() => _ReportStyleSectionState();
}

class _ReportStyleSectionState extends State<_ReportStyleSection> {
  final _samplesCtrl = TextEditingController();
  String? _styleCard;
  bool _loading = true;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _samplesCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final style = await api.getSummaryStyle();
      if (mounted) {
        setState(() {
          _styleCard = style['style_card'] as String?;
          _samplesCtrl.text = (style['samples'] as String?) ?? '';
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _distill() async {
    final text = _samplesCtrl.text.trim();
    if (text.isEmpty) {
      _snack('Paste some example text first.');
      return;
    }
    setState(() => _busy = true);
    try {
      final style = await api.distillSummaryStyle(text);
      if (mounted) {
        setState(() => _styleCard = style['style_card'] as String?);
        _snack('Style saved — summaries will use this voice.');
      }
    } catch (e) {
      if (mounted) _snack(dioErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _delete() async {
    setState(() => _busy = true);
    try {
      await api.deleteSummaryStyle();
      if (mounted) {
        setState(() {
          _styleCard = null;
          _samplesCtrl.clear();
        });
        _snack('Style removed — summaries use the neutral voice.');
      }
    } catch (e) {
      if (mounted) _snack(dioErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('REPORT STYLE', style: kStyleLabel),
        const SizedBox(height: 6),
        Text(
          'Paste texts in the voice you want (your old match reports, a '
          'commentator…). AI distills the style, and every match summary is '
          'written in it.',
          style: kStyleSecondary,
        ),
        const SizedBox(height: 10),
        if (_loading)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(color: kBrand, strokeWidth: 2),
            ),
          )
        else ...[
          TextField(
            controller: _samplesCtrl,
            maxLines: 6,
            minLines: 3,
            decoration: const InputDecoration(
              labelText: 'Example texts',
              hintText: 'Paste one or more texts in the target voice…',
              alignLabelWithHint: true,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _busy ? null : _distill,
                  icon: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : const Icon(Icons.auto_fix_high_outlined, size: 16),
                  label: Text(_busy
                      ? 'Working…'
                      : (_styleCard == null
                          ? 'Distill & save'
                          : 'Re-distill & save')),
                ),
              ),
              if (_styleCard != null) ...[
                const SizedBox(width: 8),
                IconButton(
                  tooltip: 'Remove style',
                  onPressed: _busy ? null : _delete,
                  icon: const Icon(Icons.delete_outline,
                      size: 20, color: kRedFg),
                ),
              ],
            ],
          ),
          if (_styleCard != null) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: kBrandSubtle,
                borderRadius: BorderRadius.circular(kRadiusCard),
                border: Border.all(
                  color: kBrandBorder.withValues(alpha: 0.5),
                  width: 0.5,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.style_outlined, size: 13, color: kTextBrand),
                      SizedBox(width: 5),
                      Text(
                        'Your distilled style',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                          color: kTextBrand,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _styleCard!,
                    style: const TextStyle(
                      fontSize: 13,
                      color: kTextPrimary,
                      height: 1.5,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ],
    );
  }
}
