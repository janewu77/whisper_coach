import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api/api.dart';
import '../api/client.dart';
import '../main.dart';
import '../models/match.dart';
import '../theme.dart';
import 'match_detail_screen.dart';
import 'match_review_screen.dart';

/// Match list for the currently selected team. Lives inside the [HomeShell]
/// tab scaffold (no app bar of its own). The "New match" FAB creates a match
/// against the current team.
class MatchesTab extends StatefulWidget {
  final int teamId;
  final Api? apiClient;

  const MatchesTab({super.key, required this.teamId, this.apiClient});

  @override
  State<MatchesTab> createState() => _MatchesTabState();
}

class _MatchesTabState extends State<MatchesTab> {
  late Future<List<Match>> _matches;
  final Set<int> _openingMatchIds = {};
  final _recorder = AudioRecorder();
  bool _busy = false; // extracting from photo/voice

  Api get _api => widget.apiClient ?? api;

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _matches = _api.listMatches(teamId: widget.teamId);
  }

  @override
  void didUpdateWidget(MatchesTab old) {
    super.didUpdateWidget(old);
    if (old.teamId != widget.teamId) {
      _matches = _api.listMatches(teamId: widget.teamId);
    }
  }

  Future<void> _refresh() async {
    final matches = _api.listMatches(teamId: widget.teamId);
    setState(() {
      _matches = matches;
    });
    await matches;
  }

  Future<void> _openMatch(Match match) async {
    if (_openingMatchIds.contains(match.id)) return;
    setState(() => _openingMatchIds.add(match.id));

    try {
      final details = await _api.getMatch(match.id);
      final lineup = details.lineup ??
          await _api.generateLineup(
            match.id,
            strength: match.strength,
          );
      if (!mounted) return;
      await Navigator.pushNamed(
        context,
        '/pitch',
        arguments: PitchScreenArgs(
          matchId: match.id,
          opponent: match.opponent,
          lineup: lineup,
          strength: match.strength,
        ),
      );
      if (mounted) await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _openingMatchIds.remove(match.id));
      }
    }
  }

  Future<void> _createMatch() async {
    await Navigator.pushNamed(context, '/new');
    if (mounted) await _refresh();
  }

  Future<void> _editMatch(Match match) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
    );
    if (changed == true && mounted) await _refresh();
  }

  /// Bottom sheet: choose how to add match(es).
  Future<void> _newMatchMenu() async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: kSurfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.edit_outlined, color: kTextBrand),
              title: const Text('Enter manually'),
              onTap: () => Navigator.pop(ctx, 'manual'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_back_outlined, color: kTextBrand),
              title: const Text('From a fixtures photo'),
              subtitle: const Text('Scan a schedule — review before saving'),
              onTap: () => Navigator.pop(ctx, 'photo'),
            ),
            ListTile(
              leading: const Icon(Icons.mic_none_outlined, color: kTextBrand),
              title: const Text('By voice'),
              subtitle: const Text('Say the fixtures — review before saving'),
              onTap: () => Navigator.pop(ctx, 'voice'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || choice == null) return;
    switch (choice) {
      case 'manual':
        await _createMatch();
      case 'photo':
        await _fromPhoto();
      case 'voice':
        await _fromVoice();
    }
  }

  Future<void> _openReview(List<MatchDraft> drafts) async {
    if (!mounted) return;
    if (drafts.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No matches recognised.')),
      );
      return;
    }
    final saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => MatchReviewScreen(teamId: widget.teamId, drafts: drafts),
      ),
    );
    if (saved == true && mounted) await _refresh();
  }

  Future<void> _fromPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final drafts = await _api.extractMatches(widget.teamId, picked);
      await _openReview(drafts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _fromVoice() async {
    // Record, then extract. Uses a simple dialog with a stop button.
    if (!await _recorder.hasPermission()) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Microphone permission denied.')),
        );
      }
      return;
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    late final RecordConfig config;
    String filename;
    String mime;
    String path;
    if (kIsWeb) {
      if (await _recorder.isEncoderSupported(AudioEncoder.opus)) {
        config = const RecordConfig(encoder: AudioEncoder.opus);
        filename = 'matches_$ts.webm';
        mime = 'audio/webm';
      } else {
        config = const RecordConfig(encoder: AudioEncoder.aacLc);
        filename = 'matches_$ts.m4a';
        mime = 'audio/mp4';
      }
      path = '';
    } else {
      final dir = await getTemporaryDirectory();
      filename = 'matches_$ts.m4a';
      mime = 'audio/mp4';
      path = '${dir.path}/$filename';
      config = const RecordConfig(encoder: AudioEncoder.aacLc);
    }
    await _recorder.start(config, path: path);

    // Show a "recording… stop" dialog.
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('Listening…'),
        content: const Text('Say the fixtures, e.g. "Rivals at home on Saturday, '
            'United away next week."'),
        actions: [
          ElevatedButton.icon(
            onPressed: () => Navigator.pop(ctx),
            icon: const Icon(Icons.stop_rounded, size: 18),
            label: const Text('Stop'),
          ),
        ],
      ),
    );

    final result = await _recorder.stop();
    if (!mounted || result == null) return;
    final file = XFile(result, name: filename, mimeType: mime);
    setState(() => _busy = true);
    try {
      final drafts = await _api.extractMatchesVoice(widget.teamId, file);
      await _openReview(drafts);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurfacePage,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _busy ? null : _newMatchMenu,
        backgroundColor: kBrand,
        foregroundColor: kTextOnBrand,
        elevation: 0,
        icon: _busy
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.add, size: 20),
        label: Text(_busy ? 'Reading…' : 'New match'),
      ),
      body: FutureBuilder<List<Match>>(
        future: _matches,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kBrand),
            );
          }

          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load matches',
              message: dioErrorMessage(snapshot.error!),
              actionLabel: 'Try again',
              onAction: _refresh,
            );
          }

          final matches = snapshot.data ?? const [];
          if (matches.isEmpty) {
            return _MessageState(
              icon: Icons.sports_soccer_outlined,
              title: 'No matches yet',
              message: 'Create your first match to generate a lineup.',
              actionLabel: 'Create match',
              onAction: _createMatch,
            );
          }

          return RefreshIndicator(
            color: kBrand,
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: matches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final match = matches[index];
                return _MatchCard(
                  match: match,
                  opening: _openingMatchIds.contains(match.id),
                  onTap: () => _openMatch(match),
                  onEdit: () => _editMatch(match),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final Match match;
  final bool opening;
  final VoidCallback onTap;
  final VoidCallback onEdit;

  const _MatchCard({
    required this.match,
    required this.opening,
    required this.onTap,
    required this.onEdit,
  });

  @override
  Widget build(BuildContext context) {
    final parsedDate = DateTime.tryParse(match.date);
    final dateLabel = parsedDate == null
        ? match.date
        : DateFormat('EEE, d MMM yyyy').format(parsedDate);
    final strengthLabel = switch (match.strength) {
      'strong' => 'Strong opponent',
      'weak' => 'Favourable',
      _ => 'Balanced',
    };

    return Material(
      color: kSurfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
        side: const BorderSide(color: kBorderHairline, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: opening ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kBrandSubtle,
                  borderRadius: BorderRadius.circular(kRadiusInput),
                ),
                child: const Icon(
                  Icons.sports_soccer_outlined,
                  color: kTextBrand,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'vs ${match.opponent}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kStyleBody.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$dateLabel · ${match.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kStyleSecondary,
                    ),
                    const SizedBox(height: 7),
                    _StrengthBadge(label: strengthLabel),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Edit match',
                onPressed: onEdit,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.edit_outlined,
                    size: 18, color: kTextSecondary),
              ),
              if (opening)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kBrand,
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right,
                  color: kTextTertiary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StrengthBadge extends StatelessWidget {
  final String label;

  const _StrengthBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kSurfacePage,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: kStyleLabel.copyWith(
          fontSize: 10,
          letterSpacing: 0,
          color: kTextSecondary,
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: kBrandSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: kTextBrand, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: kStyleScreenTitle,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: kStyleSecondary,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 160,
              child: ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
