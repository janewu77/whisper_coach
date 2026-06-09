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
  bool _recording = false;
  String _recFilename = 'matches.m4a';
  String _recMime = 'audio/mp4';
  String? _recPath;

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

  // ── Add from photo ─────────────────────────────────────────────────────

  Future<void> _addFromPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _busy = true);
    try {
      final drafts = await _api.extractMatches(widget.teamId, picked);
      await _openReview(drafts);
    } catch (e) {
      _snack(dioErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Add by voice (tap to record, tap to stop) ──────────────────────────

  Future<void> _toggleVoice() async {
    if (_busy) return;
    try {
      if (_recording) {
        await _stopVoiceAndReview();
      } else {
        await _startVoice();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _recording = false);
        _snack('Recording error: $e');
      }
    }
  }

  Future<void> _startVoice() async {
    if (!await _recorder.hasPermission()) {
      _snack('Microphone permission denied.');
      return;
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    late final RecordConfig config;
    if (kIsWeb) {
      if (await _recorder.isEncoderSupported(AudioEncoder.opus)) {
        config = const RecordConfig(encoder: AudioEncoder.opus);
        _recFilename = 'matches_$ts.webm';
        _recMime = 'audio/webm';
      } else {
        config = const RecordConfig(encoder: AudioEncoder.aacLc);
        _recFilename = 'matches_$ts.m4a';
        _recMime = 'audio/mp4';
      }
      _recPath = '';
    } else {
      final dir = await getTemporaryDirectory();
      _recFilename = 'matches_$ts.m4a';
      _recMime = 'audio/mp4';
      _recPath = '${dir.path}/$_recFilename';
      config = const RecordConfig(encoder: AudioEncoder.aacLc);
    }
    await _recorder.start(config, path: _recPath!);
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _stopVoiceAndReview() async {
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _busy = true;
    });
    if (path == null) {
      setState(() => _busy = false);
      return;
    }
    final file = XFile(path, name: _recFilename, mimeType: _recMime);
    try {
      final drafts = await _api.extractMatchesVoice(widget.teamId, file);
      await _openReview(drafts);
    } catch (e) {
      _snack(dioErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _snack(String m) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurfacePage,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Add by voice — same brand colour as the photo button, circle shape.
          FloatingActionButton(
            heroTag: 'matchByVoice',
            onPressed: _busy ? null : _toggleVoice,
            backgroundColor: _recording ? kRedFg : kBrand,
            foregroundColor: kTextOnBrand,
            elevation: 0,
            shape: const CircleBorder(),
            tooltip: _recording ? 'Stop & review' : 'Add by voice',
            child: (_busy && !_recording)
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : Icon(_recording ? Icons.stop_rounded : Icons.mic_none_outlined,
                    size: 22),
          ),
          const SizedBox(width: 12),
          // Add from photo.
          FloatingActionButton.extended(
            heroTag: 'matchFromPhoto',
            onPressed: (_busy || _recording) ? null : _addFromPhoto,
            backgroundColor: kBrand,
            foregroundColor: kTextOnBrand,
            elevation: 0,
            icon: _busy && !_recording
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined, size: 20),
            label: Text(_busy && !_recording ? 'Reading…' : 'Add from photo'),
          ),
        ],
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
