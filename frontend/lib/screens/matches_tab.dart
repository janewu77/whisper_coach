import 'dart:typed_data';

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
import '../models/player.dart';
import '../services/team_service.dart';
import '../theme.dart';
import '../widgets/empty_create_hint.dart';
import 'crop_screen.dart';
import 'match_detail_screen.dart';
import 'match_edit_screen.dart';
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
  // Current roster, for the per-match "available on that date" count.
  List<Player>? _roster;
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
    _loadRoster();
  }

  @override
  void didUpdateWidget(MatchesTab old) {
    super.didUpdateWidget(old);
    if (old.teamId != widget.teamId) {
      _matches = _api.listMatches(teamId: widget.teamId);
      _roster = null;
      _loadRoster();
    }
  }

  /// Load the roster so each card can show how many players are available on
  /// its date. Failures just hide the count (the list itself still works).
  Future<void> _loadRoster() async {
    try {
      final team = await _api.getTeam(widget.teamId);
      if (mounted) setState(() => _roster = team.players);
    } catch (_) {
      if (mounted) setState(() => _roster = null);
    }
  }

  Future<void> _refresh() async {
    final matches = _api.listMatches(teamId: widget.teamId);
    setState(() {
      _matches = matches;
    });
    _loadRoster();
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

  /// Start recording (live notes). Ensures a lineup exists first so in-match
  /// notes are accepted by the backend.
  Future<void> _recordMatch(Match match) async {
    if (_openingMatchIds.contains(match.id)) return;
    setState(() => _openingMatchIds.add(match.id));
    try {
      final details = await _api.getMatch(match.id);
      if (details.lineup == null) {
        await _api.generateLineup(match.id, strength: match.strength);
      }
      if (!mounted) return;
      await Navigator.pushNamed(
        context,
        '/live',
        arguments:
            LiveScreenArgs(matchId: match.id, opponent: match.opponent),
      );
      if (mounted) await _refresh();
    } catch (error) {
      if (mounted) _snack(dioErrorMessage(error));
    } finally {
      if (mounted) setState(() => _openingMatchIds.remove(match.id));
    }
  }

  /// Open the editable form (Edit button). Refreshes the list on save.
  Future<void> _editMatch(Match match) async {
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => MatchEditScreen(match: match)),
    );
    if (changed == true && mounted) await _refresh();
  }

  /// Open the read-only details view (Details button / card tap).
  void _showDetails(Match match) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => MatchDetailScreen(match: match)),
    );
  }

  Future<void> _deleteMatch(Match match) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete match?'),
        content: Text('Delete the match vs ${match.opponent}? '
            'Its lineup and notes are removed too.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRedFg),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await _api.deleteMatch(match.id);
      await _refresh();
    } catch (e) {
      _snack(dioErrorMessage(e));
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

  // ── Add from photo ─────────────────────────────────────────────────────

  Future<void> _addFromPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    // Crop to just the fixtures area before extracting (like add-player).
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => CropScreen(bytes: bytes)),
    );
    if (cropped == null) return;
    final file = XFile.fromData(
      cropped,
      name: 'fixtures_crop.jpg',
      mimeType: 'image/jpeg',
    );
    setState(() => _busy = true);
    try {
      final drafts = await _api.extractMatches(widget.teamId, file);
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
          // Add from photo (icon only).
          FloatingActionButton(
            heroTag: 'matchFromPhoto',
            onPressed: (_busy || _recording) ? null : _addFromPhoto,
            backgroundColor: kBrand,
            foregroundColor: kTextOnBrand,
            elevation: 0,
            shape: const CircleBorder(),
            tooltip: 'Add from photo',
            child: _busy && !_recording
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        color: Colors.white, strokeWidth: 2),
                  )
                : const Icon(Icons.add_a_photo_outlined, size: 22),
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
            return const EmptyCreateHint(
              title: 'No matches yet',
              message: 'Tap the mic to say your fixtures, or the camera to '
                  'upload a schedule — AI adds your matches.',
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
                final matchDate = DateTime.tryParse(match.date);
                final roster = _roster;
                // The coach's per-match list (lineup screen) wins; otherwise
                // availability derives from absences on the match date.
                final unavailableIds = match.unavailablePlayerIds;
                final available = roster == null
                    ? null
                    : unavailableIds != null
                        ? roster
                            .where((p) =>
                                p.id == null ||
                                !unavailableIds.contains(p.id))
                            .length
                        : (matchDate == null
                            ? null
                            : roster
                                .where((p) => p.availableOn(matchDate))
                                .length);
                return _MatchCard(
                  match: match,
                  ourTeam: TeamService.instance.current?.name ?? 'Our team',
                  availableCount: available,
                  rosterCount: roster?.length,
                  busy: _openingMatchIds.contains(match.id),
                  onLineup: () => _openMatch(match),
                  onRecord: () => _recordMatch(match),
                  onDetails: () => _showDetails(match),
                  onEdit: () => _editMatch(match),
                  onDelete: () => _deleteMatch(match),
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
  final String ourTeam;
  // Players available on the match date / roster size (null = unknown).
  final int? availableCount;
  final int? rosterCount;
  final bool busy;
  final VoidCallback onLineup;
  final VoidCallback onRecord;
  final VoidCallback onDetails;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _MatchCard({
    required this.match,
    required this.ourTeam,
    this.availableCount,
    this.rosterCount,
    required this.busy,
    required this.onLineup,
    required this.onRecord,
    required this.onDetails,
    required this.onEdit,
    required this.onDelete,
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
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: kBrandSubtle,
                    borderRadius: BorderRadius.circular(kRadiusInput),
                  ),
                  child: const Icon(Icons.sports_soccer_outlined,
                      color: kTextBrand, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _MatchTitle(
                        home: match.isHome ? ourTeam : match.opponent,
                        away: match.isHome ? match.opponent : ourTeam,
                        ourTeamIsHome: match.isHome,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        [
                          dateLabel,
                          if (match.kickoffTime != null &&
                              match.kickoffTime!.isNotEmpty)
                            match.kickoffTime!,
                        ].join(' ') +
                            (match.pitch != null && match.pitch!.isNotEmpty
                                ? ' · ${match.pitch}'
                                : ''),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kStyleSecondary,
                      ),
                      if (match.address != null &&
                          match.address!.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            const Icon(Icons.location_on_outlined,
                                size: 12, color: kTextTertiary),
                            const SizedBox(width: 3),
                            Expanded(
                              child: Text(
                                match.address!,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: kStyleSecondary.copyWith(
                                    color: kTextTertiary),
                              ),
                            ),
                          ],
                        ),
                      ],
                      const SizedBox(height: 7),
                      Wrap(
                        spacing: 6,
                        runSpacing: 4,
                        children: [
                          _StrengthBadge(label: strengthLabel),
                          if (availableCount != null && rosterCount != null)
                            _AvailabilityBadge(
                              available: availableCount!,
                              total: rosterCount!,
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Edit match',
                  onPressed: busy ? null : onEdit,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.edit_outlined,
                      size: 18, color: kTextTertiary),
                ),
                IconButton(
                  tooltip: 'Delete match',
                  onPressed: busy ? null : onDelete,
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline,
                      size: 18, color: kTextTertiary),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Row(
            children: [
              Expanded(
                child: _CardAction(
                  icon: Icons.grid_view_outlined,
                  label: 'Line up',
                  busy: busy,
                  onTap: busy ? null : onLineup,
                ),
              ),
              const _VDivider(),
              Expanded(
                child: _CardAction(
                  icon: Icons.play_arrow_rounded,
                  label: 'Start',
                  onTap: busy ? null : onRecord,
                ),
              ),
              const _VDivider(),
              Expanded(
                child: _CardAction(
                  icon: Icons.info_outline,
                  label: 'Details',
                  onTap: busy ? null : onDetails,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _VDivider extends StatelessWidget {
  const _VDivider();
  @override
  Widget build(BuildContext context) =>
      Container(width: 0.5, height: 22, color: kBorderHairline);
}

/// A single action in a match card's bottom row (icon + label).
class _CardAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool busy;

  const _CardAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.busy = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? kTextTertiary : kTextBrand;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (busy)
              const SizedBox(
                width: 15,
                height: 15,
                child: CircularProgressIndicator(strokeWidth: 2, color: kBrand),
              )
            else
              Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: kStyleSecondary.copyWith(
                  color: color, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

/// "Home vs Away" with our team shown in bold (home listed first).
class _MatchTitle extends StatelessWidget {
  final String home;
  final String away;
  final bool ourTeamIsHome;

  const _MatchTitle({
    required this.home,
    required this.away,
    required this.ourTeamIsHome,
  });

  @override
  Widget build(BuildContext context) {
    TextStyle s(bool ours) => kStyleBody.copyWith(
          fontSize: 15,
          fontWeight: ours ? FontWeight.w700 : FontWeight.w400,
          color: ours ? kTextPrimary : kTextSecondary,
        );
    return Text.rich(
      TextSpan(children: [
        TextSpan(text: home, style: s(ourTeamIsHome)),
        TextSpan(text: '  vs  ', style: kStyleSecondary.copyWith(fontSize: 13)),
        TextSpan(text: away, style: s(!ourTeamIsHome)),
      ]),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

/// "N/M available" on the match date — red when a full XI isn't possible.
class _AvailabilityBadge extends StatelessWidget {
  final int available;
  final int total;

  const _AvailabilityBadge({required this.available, required this.total});

  @override
  Widget build(BuildContext context) {
    final short = available < 11;
    final color = short ? kRedFg : kTextSecondary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: short ? kRedBg : kSurfacePage,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 11, color: color),
          const SizedBox(width: 3),
          Text(
            '$available/$total available',
            style: kStyleLabel.copyWith(
              fontSize: 10,
              letterSpacing: 0,
              color: color,
            ),
          ),
        ],
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
