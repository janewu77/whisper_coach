import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api/api.dart';
import '../api/client.dart';
import '../models/lineup.dart';
import '../theme.dart';
import '../widgets/pitch_view.dart';
import '../main.dart';

/// Formations offered per team size (outfield players only; GK implicit).
const Map<int, List<String>> kFormationsBySize = {
  5: ['1-2-1', '2-1-1', '1-1-2', '2-2'],
  7: ['2-3-1', '3-2-1', '2-2-2', '3-1-2'],
  11: ['4-3-3', '4-2-3-1', '3-5-2', '4-4-2'],
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

  @override
  Widget build(BuildContext context) {
    final pitchPlayers = layoutFromLineup(_lineup);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lineup · ${_lineup.formation}'),
            Text(
              'vs ${widget.args.opponent}',
              style: kStyleSecondary,
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
          // Team size selector
          const Text('TEAM SIZE', style: kStyleLabel),
          const SizedBox(height: 8),
          Row(
            children: [
              for (final size in const [5, 7, 11]) ...[
                _SelectChip(
                  label: '${size}er',
                  selected: _teamSize == size,
                  onTap: _regenerating
                      ? null
                      : () => setState(() {
                            _teamSize = size;
                            _formation = null; // size changed → re-pick
                          }),
                ),
                const SizedBox(width: 8),
              ],
            ],
          ),
          const SizedBox(height: 12),

          // Formation selector for the chosen size
          const Text('FORMATION', style: kStyleLabel),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _SelectChip(
                label: 'Auto',
                selected: _formation == null,
                onTap: _regenerating
                    ? null
                    : () => setState(() => _formation = null),
              ),
              for (final f in kFormationsBySize[_teamSize]!)
                _SelectChip(
                  label: f,
                  selected: _formation == f,
                  onTap: _regenerating
                      ? null
                      : () => setState(() => _formation = f),
                ),
            ],
          ),
          const SizedBox(height: 12),

          // Coach instructions (keyboard or voice) + generate
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: kSurfaceCard,
              borderRadius: BorderRadius.circular(kRadiusCard),
              border: Border.all(color: kBorderHairline, width: 0.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _instructionsCtrl,
                  maxLines: 2,
                  minLines: 1,
                  decoration: InputDecoration(
                    labelText: 'Instructions (optional)',
                    hintText: _recording
                        ? 'Listening… tap the mic to stop & generate'
                        : 'e.g. Max in goal, press high, Tom on the left…',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    // Voice input
                    IconButton(
                      tooltip:
                          _recording ? 'Stop & generate' : 'Speak instructions',
                      onPressed: _regenerating ? null : _toggleVoice,
                      style: IconButton.styleFrom(
                        backgroundColor: _recording ? kRedFg : kBrandSubtle,
                        foregroundColor:
                            _recording ? Colors.white : kTextBrand,
                      ),
                      icon: Icon(
                        _recording
                            ? Icons.stop_rounded
                            : Icons.mic_none_outlined,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: (_regenerating || _recording)
                            ? null
                            : () => _generate(),
                        icon: _regenerating
                            ? const SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.auto_fix_high_outlined,
                                size: 16),
                        label: Text(_regenerating
                            ? 'Generating…'
                            : 'Generate lineup'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // Pitch
          PitchView(
            players: pitchPlayers,
            selectedId: _selectedPlayerId,
            onTap: _onPlayerTap,
          ),
          const SizedBox(height: 12),

          // Starters | Subs
          _SquadColumns(starters: _lineup.lineup, subs: _lineup.subs),
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

/// A pill chip used by the team-size and formation selectors.
class _SelectChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback? onTap;

  const _SelectChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? kBrandSubtle : kSurfaceCard,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? kBrandBorder : kBorderStrong,
            width: selected ? 1.5 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: selected ? kTextBrand : kTextPrimary,
          ),
        ),
      ),
    );
  }
}

/// Starters (left) and subs (right), side by side.
class _SquadColumns extends StatelessWidget {
  final List<LineupSlot> starters;
  final List<LineupSlot> subs;

  const _SquadColumns({required this.starters, required this.subs});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _SquadList(
            title: 'STARTING · ${starters.length}',
            slots: starters,
            starter: true,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _SquadList(
            title: 'SUBS · ${subs.length}',
            slots: subs,
            starter: false,
          ),
        ),
      ],
    );
  }
}

class _SquadList extends StatelessWidget {
  final String title;
  final List<LineupSlot> slots;
  final bool starter;

  const _SquadList({
    required this.title,
    required this.slots,
    required this.starter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kSurfaceCard,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kBorderHairline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: kStyleLabel),
          const SizedBox(height: 8),
          if (slots.isEmpty)
            Text('—',
                style: kStyleSecondary.copyWith(color: kTextTertiary))
          else
            for (final s in slots)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Container(
                      width: 30,
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      decoration: BoxDecoration(
                        color: starter ? kBrandSubtle : kSurfacePage,
                        borderRadius: BorderRadius.circular(5),
                      ),
                      child: Text(
                        s.position,
                        textAlign: TextAlign.center,
                        style: kStyleLabel.copyWith(
                          fontSize: 9,
                          letterSpacing: 0,
                          color: starter ? kTextBrand : kTextSecondary,
                        ),
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        s.player,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: kStyleBodyMd.copyWith(
                          fontWeight:
                              starter ? FontWeight.w600 : FontWeight.w400,
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
                player.initials,
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
