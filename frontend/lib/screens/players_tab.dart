import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api/api.dart';
import '../api/client.dart';
import '../models/import_review.dart';
import '../models/player.dart';
import '../models/team.dart';
import '../theme.dart';
import 'crop_screen.dart';
import 'import_review_screen.dart';
import 'player_detail_screen.dart';

/// Roster view for the currently selected team. Players can be added by
/// uploading a team photo (AI extraction appends them to this team).
class PlayersTab extends StatefulWidget {
  final int teamId;

  const PlayersTab({super.key, required this.teamId});

  @override
  State<PlayersTab> createState() => _PlayersTabState();
}

enum _PlayerSort { lastName, firstName, number }

String _sortLabel(_PlayerSort s) => switch (s) {
      _PlayerSort.lastName => 'Last name',
      _PlayerSort.firstName => 'First name',
      _PlayerSort.number => 'Number',
    };

// Map each position code to a line (back/mid/front) and a side
// (left/center/right) so the list can be filtered by both.
const _kPosLine = <String, String>{
  'GK': 'back', 'CB': 'back', 'LB': 'back', 'RB': 'back',
  'LWB': 'back', 'RWB': 'back',
  'CDM': 'mid', 'CM': 'mid', 'CAM': 'mid', 'LM': 'mid', 'RM': 'mid',
  'LW': 'front', 'RW': 'front', 'ST': 'front',
};
const _kPosSide = <String, String>{
  'GK': 'center', 'CB': 'center', 'CDM': 'center', 'CM': 'center',
  'CAM': 'center', 'ST': 'center',
  'LB': 'left', 'LWB': 'left', 'LM': 'left', 'LW': 'left',
  'RB': 'right', 'RWB': 'right', 'RM': 'right', 'RW': 'right',
};
const _kLineFilters = [('back', 'Back'), ('mid', 'Midfield'), ('front', 'Front')];
const _kSideFilters = [('left', 'Left'), ('center', 'Center'), ('right', 'Right')];

class _PlayersTabState extends State<PlayersTab> {
  late Future<Team> _team;
  bool _extracting = false;
  _PlayerSort _sort = _PlayerSort.lastName;
  final Set<String> _lineFilter = {};
  final Set<String> _sideFilter = {};
  final Set<String> _availFilter = {}; // 'today' | 'nextmatch'
  DateTime? _nextMatchDate;

  bool get _filterActive =>
      _lineFilter.isNotEmpty || _sideFilter.isNotEmpty || _availFilter.isNotEmpty;

  // Voice "add player" recording state.
  final _recorder = AudioRecorder();
  bool _recording = false;
  bool _voiceBusy = false;
  String _recFilename = 'players.m4a';
  String _recMime = 'audio/mp4';
  String? _recPath;

  @override
  void initState() {
    super.initState();
    _team = api.getTeam(widget.teamId);
    _loadNextMatch();
  }

  @override
  void dispose() {
    _recorder.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(PlayersTab old) {
    super.didUpdateWidget(old);
    if (old.teamId != widget.teamId) {
      _team = api.getTeam(widget.teamId);
      _loadNextMatch();
    }
  }

  Future<void> _refresh() async {
    final team = api.getTeam(widget.teamId);
    setState(() => _team = team);
    _loadNextMatch();
    await team;
  }

  /// Find the soonest match on/after today (for the "available for next match"
  /// filter). Best-effort; ignored on error.
  Future<void> _loadNextMatch() async {
    try {
      final matches = await api.listMatches(teamId: widget.teamId);
      final today = DateUtils.dateOnly(DateTime.now());
      final upcoming = matches
          .map((m) => DateTime.tryParse(m.date))
          .whereType<DateTime>()
          .map(DateUtils.dateOnly)
          .where((d) => !d.isBefore(today))
          .toList()
        ..sort();
      if (mounted) {
        setState(() => _nextMatchDate = upcoming.isEmpty ? null : upcoming.first);
      }
    } catch (_) {
      // leave _nextMatchDate as-is
    }
  }

  // ── Sorting ────────────────────────────────────────────────────────────

  static List<String> _nameParts(String n) =>
      n.trim().isEmpty ? const [] : n.trim().split(RegExp(r'\s+'));

  static String _firstName(String n) {
    final p = _nameParts(n);
    return p.isEmpty ? '' : p.first;
  }

  static String _lastName(String n) {
    final p = _nameParts(n);
    return p.isEmpty ? '' : p.last;
  }

  /// Empty keys always sort last (so unnamed/null players go to the bottom).
  static int _cmpStr(String a, String b) {
    final ae = a.trim().isEmpty;
    final be = b.trim().isEmpty;
    if (ae && be) return 0;
    if (ae) return 1;
    if (be) return -1;
    return a.toLowerCase().compareTo(b.toLowerCase());
  }

  List<String> _playerPositions(Player p) => p.positions.isNotEmpty
      ? p.positions
      : (p.preferredPosition == null ? const [] : [p.preferredPosition!]);

  /// A player passes the active filters: a position matching the line/side
  /// groups (empty group = any) AND the availability checks.
  bool _matchesFilter(Player p) {
    if (_lineFilter.isNotEmpty || _sideFilter.isNotEmpty) {
      final posOk = _playerPositions(p).any((raw) {
        final code = raw.toUpperCase();
        final lineOk =
            _lineFilter.isEmpty || _lineFilter.contains(_kPosLine[code]);
        final sideOk =
            _sideFilter.isEmpty || _sideFilter.contains(_kPosSide[code]);
        return lineOk && sideOk;
      });
      if (!posOk) return false;
    }
    if (_availFilter.contains('today') && !p.availableOn(DateTime.now())) {
      return false;
    }
    if (_availFilter.contains('nextmatch') &&
        _nextMatchDate != null &&
        !p.availableOn(_nextMatchDate!)) {
      return false;
    }
    return true;
  }

  List<Player> _filtered(List<Player> players) =>
      _filterActive ? players.where(_matchesFilter).toList() : players;

  /// Human label for the card's availability line.
  String _availabilityLabel(Player p) {
    final today = DateUtils.dateOnly(DateTime.now());
    final active = p.activeAbsence(today);
    if (active == null) {
      // Mention an upcoming absence if one starts soon (within ~2 weeks).
      final soon = p.absences
          .map((a) => DateUtils.dateOnly(a.from))
          .where((d) => d.isAfter(today))
          .toList()
        ..sort();
      if (soon.isNotEmpty) {
        final days = soon.first.difference(today).inDays;
        if (days <= 14) return 'Available · out in ${days}d';
      }
      return 'Available';
    }
    final back = DateUtils.dateOnly(active.to).add(const Duration(days: 1));
    final days = back.difference(today).inDays;
    final kind = active.kind == 'injury' ? 'Injured' : 'On vacation';
    if (days <= 1) return '$kind · back tomorrow';
    return '$kind · back in ${days}d';
  }

  Future<void> _openFilter() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: kSurfaceCard,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
      ),
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setSheet) {
            Widget group(List<(String, String)> opts, Set<String> sel) => Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final (key, label) in opts)
                      FilterChip(
                        label: Text(label),
                        selected: sel.contains(key),
                        onSelected: (v) => setSheet(
                            () => v ? sel.add(key) : sel.remove(key)),
                        selectedColor: kBrandSubtle,
                        checkmarkColor: kTextBrand,
                      ),
                  ],
                );
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Text('Filter by position',
                            style: kStyleScreenTitle),
                        const Spacer(),
                        TextButton(
                          onPressed: () => setSheet(() {
                            _lineFilter.clear();
                            _sideFilter.clear();
                          }),
                          child: const Text('Clear'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text('LINE', style: kStyleLabel),
                    const SizedBox(height: 8),
                    group(_kLineFilters, _lineFilter),
                    const SizedBox(height: 16),
                    const Text('SIDE', style: kStyleLabel),
                    const SizedBox(height: 8),
                    group(_kSideFilters, _sideFilter),
                    const SizedBox(height: 16),
                    const Text('AVAILABILITY', style: kStyleLabel),
                    const SizedBox(height: 8),
                    group([
                      ('today', 'Available today'),
                      (
                        'nextmatch',
                        _nextMatchDate == null
                            ? 'Available next match'
                            : 'Next match (${DateFormat('d MMM').format(_nextMatchDate!)})'
                      ),
                    ], _availFilter),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx),
                        child: const Text('Done'),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    if (mounted) setState(() {}); // re-filter the list with the new selection
  }

  List<Player> _sorted(List<Player> players) {
    final list = [...players];
    switch (_sort) {
      case _PlayerSort.firstName:
        list.sort((a, b) => _cmpStr(_firstName(a.name), _firstName(b.name)));
      case _PlayerSort.lastName:
        list.sort((a, b) => _cmpStr(_lastName(a.name), _lastName(b.name)));
      case _PlayerSort.number:
        list.sort((a, b) {
          if (a.number == null && b.number == null) return 0;
          if (a.number == null) return 1; // null number last
          if (b.number == null) return -1;
          return a.number!.compareTo(b.number!);
        });
    }
    return list;
  }

  Future<void> _editPlayer(Player p) async {
    if (p.id == null) return;
    final changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => PlayerDetailScreen(
          teamId: widget.teamId,
          playerId: p.id!,
          initialName: p.name,
        ),
      ),
    );
    if (changed == true && mounted) await _refresh();
  }

  Future<void> _deletePlayer(int playerId, String name) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Remove player?'),
        content: Text('Remove $name from this team\'s roster?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: kRedFg),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await api.deletePlayer(widget.teamId, playerId);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
      }
    }
  }

  Future<void> _addFromPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;

    // Let the coach crop to just the roster area; only that region is imported.
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => CropScreen(bytes: bytes)),
    );
    if (cropped == null) return; // cancelled crop → don't import
    final file = XFile.fromData(
      cropped,
      name: 'roster_crop.jpg',
      mimeType: 'image/jpeg',
    );

    setState(() => _extracting = true);
    try {
      // Stage the import for review — nothing is saved until the coach confirms.
      final review = await api.createImport(widget.teamId, file);
      if (!mounted) return;
      setState(() => _extracting = false);
      await _openReview(review);
    } catch (e) {
      if (mounted) {
        setState(() => _extracting = false);
        _showError(dioErrorMessage(e));
      }
    }
  }

  /// Open the review screen for a staged import; refresh the roster on confirm.
  Future<void> _openReview(ImportReview review) async {
    if (!mounted) return;
    final confirmed = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => ImportReviewScreen(review: review)),
    );
    if (confirmed == true && mounted) await _refresh();
  }

  // ── Add by voice ───────────────────────────────────────────────────────

  Future<void> _toggleVoice() async {
    if (_voiceBusy) return;
    try {
      if (_recording) {
        await _stopVoiceAndStage();
      } else {
        await _startVoice();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recording = false;
          _voiceBusy = false;
        });
        _showError('Recording error: $e');
      }
    }
  }

  Future<void> _startVoice() async {
    if (!await _recorder.hasPermission()) {
      _showError('Microphone permission denied.');
      return;
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    late final RecordConfig config;
    if (kIsWeb) {
      if (await _recorder.isEncoderSupported(AudioEncoder.opus)) {
        config = const RecordConfig(encoder: AudioEncoder.opus);
        _recFilename = 'players_$ts.webm';
        _recMime = 'audio/webm';
      } else if (await _recorder.isEncoderSupported(AudioEncoder.aacLc)) {
        config = const RecordConfig(encoder: AudioEncoder.aacLc);
        _recFilename = 'players_$ts.m4a';
        _recMime = 'audio/mp4';
      } else {
        config = const RecordConfig(encoder: AudioEncoder.wav);
        _recFilename = 'players_$ts.wav';
        _recMime = 'audio/wav';
      }
      _recPath = ''; // record_web returns a Blob URL from stop()
    } else {
      final dir = await getTemporaryDirectory();
      _recFilename = 'players_$ts.m4a';
      _recMime = 'audio/mp4';
      _recPath = '${dir.path}/$_recFilename';
      config = const RecordConfig(encoder: AudioEncoder.aacLc);
    }
    await _recorder.start(config, path: _recPath!);
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _stopVoiceAndStage() async {
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _recording = false;
      _voiceBusy = true;
    });
    if (path == null) {
      setState(() => _voiceBusy = false);
      return;
    }
    final file = XFile(path, name: _recFilename, mimeType: _recMime);
    try {
      final review = await api.createImportFromVoice(widget.teamId, file);
      if (!mounted) return;
      setState(() => _voiceBusy = false);
      await _openReview(review);
    } catch (e) {
      if (mounted) {
        setState(() => _voiceBusy = false);
        _showError(dioErrorMessage(e));
      }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurfacePage,
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Add by voice — speak the player(s), then review before saving.
          FloatingActionButton(
            heroTag: 'addByVoice',
            onPressed: _extracting ? null : _toggleVoice,
            backgroundColor: _recording ? kRedFg : kBrand,
            foregroundColor: kTextOnBrand,
            elevation: 0,
            shape: const CircleBorder(),
            tooltip: _recording ? 'Stop & add' : 'Add by voice',
            child: _voiceBusy
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
          // Add from photo — crop, then review (icon only).
          FloatingActionButton(
            heroTag: 'addFromPhoto',
            onPressed: (_extracting || _recording || _voiceBusy)
                ? null
                : _addFromPhoto,
            backgroundColor: kBrand,
            foregroundColor: kTextOnBrand,
            elevation: 0,
            shape: const CircleBorder(),
            tooltip: 'Add from photo',
            child: _extracting
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
      body: FutureBuilder<Team>(
        future: _team,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kBrand));
          }
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load players',
              message: dioErrorMessage(snapshot.error!),
              actionLabel: 'Try again',
              onAction: _refresh,
            );
          }
          final all = snapshot.data?.players ?? const <Player>[];
          if (all.isEmpty) {
            return _Message(
              icon: Icons.person_add_alt_outlined,
              title: 'No players yet',
              message:
                  'Upload a team photo and AI will extract the player names.',
              actionLabel: 'Add from photo',
              onAction: _addFromPhoto,
            );
          }
          final players = _sorted(_filtered(all));
          return RefreshIndicator(
            color: kBrand,
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: players.isEmpty ? 2 : players.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      children: [
                        Text(
                          '${players.length} '
                          '${players.length == 1 ? 'PLAYER' : 'PLAYERS'}',
                          style: kStyleLabel,
                        ),
                        const Spacer(),
                        _FilterButton(
                          active: _filterActive,
                          count: _lineFilter.length + _sideFilter.length,
                          onTap: _openFilter,
                        ),
                        const SizedBox(width: 4),
                        PopupMenuButton<_PlayerSort>(
                          tooltip: 'Sort players',
                          initialValue: _sort,
                          onSelected: (s) => setState(() => _sort = s),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(kRadiusInput),
                          ),
                          itemBuilder: (_) => [
                            for (final s in _PlayerSort.values)
                              PopupMenuItem(
                                value: s,
                                child: Row(
                                  children: [
                                    Expanded(child: Text(_sortLabel(s))),
                                    if (s == _sort)
                                      const Icon(Icons.check,
                                          size: 16, color: kBrand),
                                  ],
                                ),
                              ),
                          ],
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.swap_vert,
                                  size: 16, color: kTextSecondary),
                              const SizedBox(width: 4),
                              Text('Sort: ${_sortLabel(_sort)}',
                                  style: kStyleSecondary),
                              const Icon(Icons.expand_more,
                                  size: 16, color: kTextSecondary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (players.isEmpty) {
                  return const Padding(
                    padding: EdgeInsets.only(top: 40),
                    child: Center(
                      child: Text('No players match the filter.',
                          style: kStyleSecondary),
                    ),
                  );
                }
                final p = players[index - 1];
                return _PlayerTile(
                  name: p.name,
                  number: p.number,
                  positions: p.positions.isNotEmpty
                      ? p.positions
                      : (p.preferredPosition == null
                          ? const []
                          : [p.preferredPosition!]),
                  availabilityLabel: _availabilityLabel(p),
                  available: p.availableOn(DateTime.now()),
                  injuredNow:
                      p.activeAbsence(DateTime.now())?.kind == 'injury',
                  onEdit: p.id == null ? null : () => _editPlayer(p),
                  onDelete: p.id == null
                      ? null
                      : () => _deletePlayer(p.id!, p.name),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  final bool active;
  final int count;
  final VoidCallback onTap;

  const _FilterButton({
    required this.active,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = active ? kBrand : kTextSecondary;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.filter_list, size: 16, color: color),
            const SizedBox(width: 4),
            Text(
              active ? 'Filter ($count)' : 'Filter',
              style: kStyleSecondary.copyWith(
                color: color,
                fontWeight: active ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final String name;
  final int? number;
  final List<String> positions;
  final String availabilityLabel;
  final bool available;
  final bool injuredNow;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _PlayerTile({
    required this.name,
    this.number,
    this.positions = const [],
    this.availabilityLabel = 'Available',
    this.available = true,
    this.injuredNow = false,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final subtitle = positions.join(' · ');
    final Color statusFg =
        available ? kGreenFg : (injuredNow ? kRedFg : kAmberFg);
    final Color statusBg =
        available ? kGreenBg : (injuredNow ? kRedBg : kAmberBg);
    final IconData statusIcon = available
        ? Icons.check_circle_outline
        : (injuredNow ? Icons.healing_outlined : Icons.beach_access_outlined);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: kSurfaceCard,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kBorderHairline, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kBrandSubtle,
              borderRadius: BorderRadius.circular(kRadiusInput),
            ),
            child: Text(
              number?.toString() ?? '–',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kTextBrand,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kStyleBody.copyWith(fontWeight: FontWeight.w500),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: kStyleSecondary),
                ],
                const SizedBox(height: 5),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(100),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(statusIcon, size: 11, color: statusFg),
                      const SizedBox(width: 4),
                      Text(
                        availabilityLabel,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: statusFg,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (onEdit != null)
            IconButton(
              tooltip: 'Edit player',
              onPressed: onEdit,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.edit_outlined,
                size: 19,
                color: kTextSecondary,
              ),
            ),
          if (onDelete != null)
            IconButton(
              tooltip: 'Remove player',
              onPressed: onDelete,
              visualDensity: VisualDensity.compact,
              icon: const Icon(
                Icons.delete_outline,
                size: 20,
                color: kTextTertiary,
              ),
            ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _Message({
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
            Text(title, textAlign: TextAlign.center, style: kStyleScreenTitle),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: kStyleSecondary),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
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
