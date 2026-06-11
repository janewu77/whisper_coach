import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api/api.dart';
import '../api/client.dart';
import '../models/lineup.dart';
import '../models/player.dart';
import '../theme.dart';
import '../widgets/pitch_view.dart';
import '../main.dart';

/// Formations offered per team size (outfield players only; GK implicit).
const Map<int, List<String>> kFormationsBySize = {
  5: ['1-2-1', '2-1-1', '1-1-2', '2-2'],
  7: ['2-3-1', '3-2-1', '2-2-2', '3-1-2'],
  11: ['4-3-3', '4-2-3-1', '3-5-2', '4-4-2', '3-3-3-1'],
};

class PitchScreen extends StatefulWidget {
  final PitchScreenArgs args;

  const PitchScreen({super.key, required this.args});

  @override
  State<PitchScreen> createState() => _PitchScreenState();
}

class _PitchScreenState extends State<PitchScreen> {
  late Lineup _lineup;
  bool _regenerating = false;
  String? _selectedPlayerId;

  // Generation options.
  late int _teamSize; // 5 | 7 | 11
  String? _formation; // null = let the AI pick
  final _instructionsCtrl = TextEditingController();

  // Squad availability (tap a player to move them between the two lists;
  // persisted on the match so generation only uses available players).
  List<Player>? _roster;
  final Set<int> _unavailable = {};
  bool _squadExpanded = false; // collapsed by default to save screen space

  // Voice instructions.
  final _recorder = AudioRecorder();
  bool _recording = false;
  String _recFilename = 'lineup.m4a';
  String _recMime = 'audio/mp4';
  String? _recPath;

  @override
  void initState() {
    super.initState();
    _lineup = widget.args.lineup;
    final n = _lineup.lineup.length;
    _teamSize = n <= 5 ? 5 : (n <= 7 ? 7 : 11);
    _loadSquad();
  }

  /// Load the roster + this match's availability. The stored per-match list
  /// wins; otherwise players whose absence covers the match date start out.
  Future<void> _loadSquad() async {
    try {
      final details = await api.getMatch(widget.args.matchId);
      final team = await api.getTeam(details.match.teamId);
      final unavail = <int>{};
      final stored = details.match.unavailablePlayerIds;
      if (stored != null) {
        unavail.addAll(stored);
      } else {
        final matchDate = DateTime.tryParse(details.match.date);
        if (matchDate != null) {
          for (final p in team.players) {
            if (p.id != null && !p.availableOn(matchDate)) unavail.add(p.id!);
          }
        }
      }
      if (mounted) {
        setState(() {
          _roster = team.players;
          _unavailable
            ..clear()
            ..addAll(unavail);
        });
      }
    } catch (_) {
      // Availability section simply stays hidden when loading fails.
    }
  }

  /// Move a player between Available and Out, persisting on the match.
  Future<void> _toggleAvailability(Player p) async {
    final id = p.id;
    if (id == null || _regenerating) return;
    final wasOut = _unavailable.contains(id);
    setState(() => wasOut ? _unavailable.remove(id) : _unavailable.add(id));
    try {
      await api.updateMatch(
        widget.args.matchId,
        unavailablePlayerIds: _unavailable.toList(),
      );
    } catch (e) {
      if (mounted) {
        setState(
            () => wasOut ? _unavailable.add(id) : _unavailable.remove(id));
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dioErrorMessage(e))),
        );
      }
    }
  }

  /// Short display name: nickname, else first name + last-name initial.
  static String _shortName(Player p) {
    if (p.nickname != null && p.nickname!.isNotEmpty) return p.nickname!;
    final parts = p.name.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return p.name;
    return '${parts.first} ${parts.last[0]}.';
  }

  @override
  void dispose() {
    _instructionsCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _generate({XFile? voice}) async {
    setState(() => _regenerating = true);
    try {
      final newLineup = voice != null
          ? await api.generateLineupVoice(
              widget.args.matchId,
              voice,
              teamSize: _teamSize,
              formation: _formation,
            )
          : await api.generateLineup(
              widget.args.matchId,
              strength: widget.args.strength,
              teamSize: _teamSize,
              formation: _formation,
              instructions: _instructionsCtrl.text.trim(),
            );
      setState(() {
        _lineup = newLineup;
        _selectedPlayerId = null;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(dioErrorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  // ── Voice instructions (tap mic to record, tap again to generate) ────────

  Future<void> _toggleVoice() async {
    if (_regenerating) return;
    try {
      if (_recording) {
        await _stopVoiceAndGenerate();
      } else {
        await _startVoice();
      }
    } catch (e) {
      if (mounted) {
        setState(() => _recording = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Recording error: $e')),
        );
      }
    }
  }

  Future<void> _startVoice() async {
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
    if (kIsWeb) {
      if (await _recorder.isEncoderSupported(AudioEncoder.opus)) {
        config = const RecordConfig(encoder: AudioEncoder.opus);
        _recFilename = 'lineup_$ts.webm';
        _recMime = 'audio/webm';
      } else {
        config = const RecordConfig(encoder: AudioEncoder.aacLc);
        _recFilename = 'lineup_$ts.m4a';
        _recMime = 'audio/mp4';
      }
      _recPath = '';
    } else {
      final dir = await getTemporaryDirectory();
      _recFilename = 'lineup_$ts.m4a';
      _recMime = 'audio/mp4';
      _recPath = '${dir.path}/$_recFilename';
      config = const RecordConfig(encoder: AudioEncoder.aacLc);
    }
    await _recorder.start(config, path: _recPath!);
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _stopVoiceAndGenerate() async {
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (path == null) return;
    await _generate(
      voice: XFile(path, name: _recFilename, mimeType: _recMime),
    );
  }

  void _onPlayerTap(PitchPlayer player) {
    setState(() {
      _selectedPlayerId =
          _selectedPlayerId == player.id ? null : player.id;
    });
  }

  // ── Drag & drop edits (swap positions / pitch ↔ bench) ──────────────────

  /// Two starters swap positions (players stay, position codes trade).
  void _swapStarters(int a, int b) {
    if (a == b) return;
    final sa = _lineup.lineup[a];
    final sb = _lineup.lineup[b];
    setState(() {
      _lineup.lineup[a] = LineupSlot(
          player: sa.player, position: sb.position, nickname: sa.nickname);
      _lineup.lineup[b] = LineupSlot(
          player: sb.player, position: sa.position, nickname: sb.nickname);
      _selectedPlayerId = null;
    });
    _saveLineup();
  }

  /// A sub takes a starter's place (and position); the starter is benched.
  void _swapWithBench(int starterIdx, int subIdx) {
    final starter = _lineup.lineup[starterIdx];
    final sub = _lineup.subs[subIdx];
    setState(() {
      _lineup.lineup[starterIdx] = LineupSlot(
          player: sub.player,
          position: starter.position,
          nickname: sub.nickname);
      _lineup.subs[subIdx] = LineupSlot(
          player: starter.player,
          position: starter.position,
          nickname: starter.nickname);
      _selectedPlayerId = null;
    });
    _saveLineup();
  }

  /// Persist the manual arrangement (fire-and-forget with an error snack).
  Future<void> _saveLineup() async {
    try {
      await api.saveLineup(widget.args.matchId, _lineup);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Could not save: ${dioErrorMessage(e)}')),
        );
      }
    }
  }

  void _startMatch() {
    Navigator.pushNamed(
      context,
      '/live',
      arguments: LiveScreenArgs(
        matchId: widget.args.matchId,
        opponent: widget.args.opponent,
      ),
    );
  }

  Widget _availabilityRow({
    required String title,
    required List<Player> players,
    required bool out,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('$title · ${players.length}', style: kStyleLabel),
        const SizedBox(height: 6),
        if (players.isEmpty)
          Text(out ? 'Everyone can play.' : 'No one available — tap below.',
              style: kStyleSecondary.copyWith(color: kTextTertiary))
        else
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in players)
                GestureDetector(
                  onTap: () => _toggleAvailability(p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: out ? kRedBg : kBrandSubtle,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: out ? kRedFg.withOpacity(0.3) : kBrandBorder,
                        width: 0.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          out
                              ? Icons.person_off_outlined
                              : Icons.check_circle_outline,
                          size: 12,
                          color: out ? kRedFg : kTextBrand,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          _shortName(p),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: out ? kRedFg : kTextBrand,
                            decoration:
                                out ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final pitchPlayers = layoutFromLineup(_lineup);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lineup · ${_lineup.formation}',
                maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(
              'vs ${widget.args.opponent}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: kStyleSecondary.copyWith(fontSize: 12, height: 1.2),
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: kSurfaceInverse,
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.memory_outlined,
                    size: 11, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_regenerating ? 2.5 : 0.5),
          child: _regenerating
              ? const LinearProgressIndicator(
                  minHeight: 2.5, color: kBrand, backgroundColor: kBrandSubtle)
              : Container(height: 0.5, color: kBorderHairline),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Squad availability: collapsible block (header shows the counts);
          // expanded, tap a player to move them to the other list.
          if (_roster != null) ...[
            InkWell(
              onTap: () =>
                  setState(() => _squadExpanded = !_squadExpanded),
              borderRadius: BorderRadius.circular(6),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    const Icon(Icons.groups_2_outlined,
                        size: 14, color: kTextSecondary),
                    const SizedBox(width: 6),
                    Text(
                      'SQUAD · '
                      '${_roster!.length - _unavailable.length} available'
                      '${_unavailable.isNotEmpty ? ' · ${_unavailable.length} out' : ''}',
                      style: kStyleLabel,
                    ),
                    const Spacer(),
                    Icon(
                      _squadExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      size: 18,
                      color: kTextSecondary,
                    ),
                  ],
                ),
              ),
            ),
            if (_squadExpanded) ...[
              const SizedBox(height: 8),
              _availabilityRow(
                title: 'AVAILABLE',
                players: _roster!
                    .where((p) => !_unavailable.contains(p.id))
                    .toList(),
                out: false,
              ),
              const SizedBox(height: 10),
              _availabilityRow(
                title: 'NOT AVAILABLE',
                players: _roster!
                    .where((p) => _unavailable.contains(p.id))
                    .toList(),
                out: true,
              ),
            ],
            const SizedBox(height: 12),
          ],

          // Team size + formation, side by side (dropdowns to save space).
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: _teamSize,
                  isDense: true,
                  decoration: const InputDecoration(
                      labelText: 'Team size', isDense: true),
                  items: [
                    for (final size in const [5, 7, 11])
                      DropdownMenuItem(value: size, child: Text('${size}er')),
                  ],
                  onChanged: _regenerating
                      ? null
                      : (v) => setState(() {
                            _teamSize = v ?? _teamSize;
                            _formation = null; // size changed → re-pick
                          }),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: DropdownButtonFormField<String>(
                  value: _formation ?? 'Auto',
                  isDense: true,
                  decoration: const InputDecoration(
                      labelText: 'Formation', isDense: true),
                  items: [
                    for (final f in ['Auto', ...kFormationsBySize[_teamSize]!])
                      DropdownMenuItem(value: f, child: Text(f)),
                  ],
                  onChanged: _regenerating
                      ? null
                      : (v) => setState(
                          () => _formation = (v == null || v == 'Auto')
                              ? null
                              : v),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Instructions input with the mic inside it + icon-only Generate,
          // all on one line.
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _instructionsCtrl,
                  maxLines: 1,
                  decoration: InputDecoration(
                    labelText: 'Instructions (optional)',
                    hintText: _recording
                        ? 'Listening… tap the mic to stop & generate'
                        : 'e.g. Max in goal, press high…',
                    isDense: true,
                    suffixIcon: IconButton(
                      tooltip: _recording
                          ? 'Stop & generate'
                          : 'Speak instructions',
                      onPressed: _regenerating ? null : _toggleVoice,
                      icon: Icon(
                        _recording
                            ? Icons.stop_rounded
                            : Icons.mic_none_outlined,
                        size: 20,
                        color: _recording ? kRedFg : kTextBrand,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton(
                tooltip: 'Generate lineup',
                onPressed: (_regenerating || _recording)
                    ? null
                    : () => _generate(),
                style: IconButton.styleFrom(
                  backgroundColor: kBrand,
                  foregroundColor: kTextOnBrand,
                  disabledBackgroundColor: kBorderStrong,
                  fixedSize: const Size(46, 46),
                ),
                icon: _regenerating
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.auto_fix_high_outlined, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Pitch (3/4) with the subs list to its right (1/4). The row gets an
          // explicit height (pitch width / aspect ratio) because it sits in a
          // ListView, where stretch + inner Expanded have no bounded height.
          LayoutBuilder(
            builder: (context, constraints) {
              const gap = 8.0;
              final pitchW = (constraints.maxWidth - gap) * 3 / 4;
              final rowH = pitchW / 0.65; // PitchView aspect ratio
              return SizedBox(
                height: rowH,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      flex: 3,
                      child: PitchView(
                        players: pitchPlayers,
                        selectedId: _selectedPlayerId,
                        onTap: _onPlayerTap,
                        onSwapStarters: _swapStarters,
                        onSubIn: (subIdx, starterIdx) =>
                            _swapWithBench(starterIdx, subIdx),
                      ),
                    ),
                    const SizedBox(width: gap),
                    Expanded(
                      flex: 1,
                      child: _SubsPanel(
                        subs: _lineup.subs,
                        onStarterDropped: _swapWithBench,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
          const SizedBox(height: 6),
          Text(
            'Hold & drag a player to swap positions — or between pitch and bench.',
            style: kStyleSecondary.copyWith(fontSize: 11, color: kTextTertiary),
          ),
          const SizedBox(height: 12),

          // AI reasoning card
          _ReasoningCard(reason: _lineup.reason),
          const SizedBox(height: 12),

          // Selected player info
          if (_selectedPlayerId != null) ...[
            _SelectedPlayerCard(
              player: pitchPlayers.firstWhere(
                (p) => p.id == _selectedPlayerId,
              ),
            ),
            const SizedBox(height: 12),
          ],

          ElevatedButton.icon(
            onPressed: _startMatch,
            icon: const Icon(Icons.play_arrow_outlined, size: 18),
            label: const Text('Start match'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

/// Narrow bench panel beside the pitch (scrolls when the bench is long).
/// Long-press-drag a sub onto a pitch dot to sub them in; drop a starter on a
/// bench entry to swap them out.
class _SubsPanel extends StatelessWidget {
  final List<LineupSlot> subs;
  final void Function(int starterIndex, int subIndex)? onStarterDropped;

  const _SubsPanel({required this.subs, this.onStarterDropped});

  Widget _entry(LineupSlot s, {bool dragging = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: dragging
          ? BoxDecoration(
              color: kSurfaceCard,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: kBrandBorder),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            s.displayName, // full nickname, or the name
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: kTextPrimary,
              height: 1.2,
            ),
          ),
          Text(
            s.position,
            style: kStyleLabel.copyWith(
              fontSize: 8.5,
              letterSpacing: 0,
              color: kTextTertiary,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(8, 10, 8, 8),
      decoration: BoxDecoration(
        color: kSurfaceCard,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kBorderHairline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('SUBS · ${subs.length}',
              style: kStyleLabel.copyWith(fontSize: 9, letterSpacing: 0.3)),
          const SizedBox(height: 8),
          if (subs.isEmpty)
            Text('—', style: kStyleSecondary.copyWith(color: kTextTertiary))
          else
            Expanded(
              child: ListView(
                padding: EdgeInsets.zero,
                children: [
                  for (var i = 0; i < subs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: DragTarget<Object>(
                        onWillAcceptWithDetails: (d) =>
                            d.data is StarterDrag && onStarterDropped != null,
                        onAcceptWithDetails: (d) => onStarterDropped!
                            ((d.data as StarterDrag).index, i),
                        builder: (context, candidates, _) =>
                            LongPressDraggable<Object>(
                          data: SubDrag(i),
                          delay: const Duration(milliseconds: 200),
                          feedback: Material(
                            color: Colors.transparent,
                            child: SizedBox(
                                width: 90,
                                child: _entry(subs[i], dragging: true)),
                          ),
                          childWhenDragging:
                              Opacity(opacity: 0.3, child: _entry(subs[i])),
                          child: Container(
                            decoration: candidates.isEmpty
                                ? null
                                : BoxDecoration(
                                    color: kBrandSubtle,
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                            child: _entry(subs[i]),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ReasoningCard extends StatelessWidget {
  final String reason;

  const _ReasoningCard({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBrandSubtle,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kBrandBorder.withOpacity(0.5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  size: 13, color: kTextBrand),
              SizedBox(width: 5),
              Text(
                'AI reasoning',
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
            reason,
            style: const TextStyle(
              fontSize: 13,
              color: kTextPrimary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedPlayerCard extends StatelessWidget {
  final PitchPlayer player;

  const _SelectedPlayerCard({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
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
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kBrand,
              border: Border.all(color: kBrandPressed, width: 2),
            ),
            child: Center(
              child: Text(
                player.initials,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: kTextOnBrand,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.label,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              Text(
                player.position,
                style: const TextStyle(
                    fontSize: 12, color: kTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
