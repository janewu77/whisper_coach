import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api/api.dart';
import '../api/client.dart';
import '../models/player.dart';
import '../theme.dart';

const _kPositions = [
  'GK', 'CB', 'LB', 'RB', 'LWB', 'RWB',
  'CDM', 'CM', 'CAM', 'LM', 'RM', 'LW', 'RW', 'ST',
];

const _kTraits = [
  'Strong', 'Fast', 'Good ball control', 'Good passing', 'Good finishing',
  'Good vision', 'Stamina', 'Aerial', 'Leadership', 'Tackling', 'Composure',
];

const _kFeet = ['left', 'right', 'both'];

/// Detail / edit view for one player. Fields are grouped (identity, positions,
/// physical, strengths, notes). The coach can also speak a description and the
/// LLM fills the fields in (merged into the form — saved only on "Save").
class PlayerDetailScreen extends StatefulWidget {
  final int teamId;
  final int playerId;
  final String initialName;

  const PlayerDetailScreen({
    super.key,
    required this.teamId,
    required this.playerId,
    required this.initialName,
  });

  @override
  State<PlayerDetailScreen> createState() => _PlayerDetailScreenState();
}

class _PlayerDetailScreenState extends State<PlayerDetailScreen> {
  final _nameCtrl = TextEditingController();
  final _numberCtrl = TextEditingController();
  final _heightCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _traitCtrl = TextEditingController();

  final List<String> _positions = [];
  final List<String> _traits = [];
  String? _foot;

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  // Voice profiling.
  final _recorder = AudioRecorder();
  bool _recording = false;
  bool _voiceBusy = false;
  String _recFilename = 'profile.m4a';
  String _recMime = 'audio/mp4';
  String? _recPath;

  @override
  void initState() {
    super.initState();
    _nameCtrl.text = widget.initialName;
    _load();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _numberCtrl.dispose();
    _heightCtrl.dispose();
    _descCtrl.dispose();
    _traitCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final p = await api.getPlayer(widget.teamId, widget.playerId);
      if (!mounted) return;
      setState(() {
        _applyPlayer(p, replaceName: true);
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _loadError = dioErrorMessage(e);
          _loading = false;
        });
      }
    }
  }

  /// Fill the form from a player profile. Used by initial load and by the
  /// voice/LLM "describe" result (which merges into the existing profile).
  void _applyPlayer(Player p, {bool replaceName = false}) {
    if (replaceName) _nameCtrl.text = p.name;
    if (p.number != null) _numberCtrl.text = p.number.toString();
    if (p.heightCm != null) _heightCtrl.text = p.heightCm.toString();
    if (p.positions.isNotEmpty) {
      _positions
        ..clear()
        ..addAll(p.positions);
    }
    if (p.traits.isNotEmpty) {
      _traits
        ..clear()
        ..addAll(p.traits);
    }
    if (p.preferredFoot != null) _foot = p.preferredFoot;
    if (p.description != null && p.description!.isNotEmpty) {
      _descCtrl.text = p.description!;
    }
  }

  // ── Voice describe ───────────────────────────────────────────────────────

  Future<void> _toggleVoice() async {
    if (_voiceBusy) return;
    try {
      if (_recording) {
        await _stopAndDescribe();
      } else {
        await _startVoice();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _recording = false;
          _voiceBusy = false;
        });
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
        _recFilename = 'profile_$ts.webm';
        _recMime = 'audio/webm';
      } else if (await _recorder.isEncoderSupported(AudioEncoder.aacLc)) {
        config = const RecordConfig(encoder: AudioEncoder.aacLc);
        _recFilename = 'profile_$ts.m4a';
        _recMime = 'audio/mp4';
      } else {
        config = const RecordConfig(encoder: AudioEncoder.wav);
        _recFilename = 'profile_$ts.wav';
        _recMime = 'audio/wav';
      }
      _recPath = '';
    } else {
      final dir = await getTemporaryDirectory();
      _recFilename = 'profile_$ts.m4a';
      _recMime = 'audio/mp4';
      _recPath = '${dir.path}/$_recFilename';
      config = const RecordConfig(encoder: AudioEncoder.aacLc);
    }
    await _recorder.start(config, path: _recPath!);
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _stopAndDescribe() async {
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
      final p = await api.describePlayerVoice(
        widget.teamId,
        widget.playerId,
        file,
      );
      if (!mounted) return;
      setState(() {
        _applyPlayer(p);
        _voiceBusy = false;
      });
      _snack('Profile updated from your description — review and Save.');
    } catch (e) {
      if (mounted) {
        setState(() => _voiceBusy = false);
        _snack(dioErrorMessage(e));
      }
    }
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _snack('Name is required.');
      return;
    }
    setState(() => _saving = true);
    try {
      await api.updatePlayer(
        widget.teamId,
        widget.playerId,
        name: name,
        number: int.tryParse(_numberCtrl.text.trim()),
        positions: _positions,
        preferredPosition: _positions.isNotEmpty ? _positions.first : null,
        preferredFoot: _foot,
        heightCm: int.tryParse(_heightCtrl.text.trim()),
        traits: _traits,
        description: _descCtrl.text.trim(),
      );
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(dioErrorMessage(e));
      }
    }
  }

  void _snack(String m) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  void _togglePosition(String code) {
    setState(() {
      if (_positions.contains(code)) {
        _positions.remove(code);
      } else {
        _positions.add(code);
      }
    });
  }

  void _toggleTrait(String trait) {
    setState(() {
      final i = _traits.indexWhere((t) => t.toLowerCase() == trait.toLowerCase());
      if (i >= 0) {
        _traits.removeAt(i);
      } else {
        _traits.add(trait);
      }
    });
  }

  void _addCustomTrait() {
    final t = _traitCtrl.text.trim();
    if (t.isEmpty) return;
    if (!_traits.any((x) => x.toLowerCase() == t.toLowerCase())) {
      setState(() => _traits.add(t));
    }
    _traitCtrl.clear();
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_nameCtrl.text.isEmpty ? 'Player' : _nameCtrl.text),
        actions: [
          if (!_loading && _loadError == null)
            TextButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                          color: kBrand, strokeWidth: 2),
                    )
                  : const Text('Save',
                      style: TextStyle(fontWeight: FontWeight.w600)),
            ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: kBorderHairline),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: kBrand))
          : _loadError != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Text(_loadError!, textAlign: TextAlign.center),
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                  children: [
                    _voiceCard(),
                    const SizedBox(height: 12),
                    _group('IDENTITY', [
                      TextField(
                        controller: _nameCtrl,
                        decoration: const InputDecoration(labelText: 'Name *'),
                        onChanged: (_) => setState(() {}), // refresh app-bar title
                      ),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _numberCtrl,
                        keyboardType: TextInputType.number,
                        decoration:
                            const InputDecoration(labelText: 'Jersey number'),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _group('POSITIONS THEY CAN PLAY', [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _kPositions
                            .map((c) => FilterChip(
                                  label: Text(c),
                                  selected: _positions.contains(c),
                                  onSelected: (_) => _togglePosition(c),
                                  selectedColor: kBrandSubtle,
                                  checkmarkColor: kTextBrand,
                                ))
                            .toList(),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _group('PHYSICAL', [
                      const Text('Preferred foot', style: kStyleSecondary),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: _kFeet
                            .map((f) => ChoiceChip(
                                  label: Text(f[0].toUpperCase() + f.substring(1)),
                                  selected: _foot == f,
                                  onSelected: (_) =>
                                      setState(() => _foot = _foot == f ? null : f),
                                  selectedColor: kBrandSubtle,
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _heightCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Height',
                          suffixText: 'cm',
                        ),
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _group('STRENGTHS & TRAITS', [
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: <Widget>[
                          for (final t in _traitOptions())
                            FilterChip(
                              label: Text(t),
                              selected: _traits
                                  .any((x) => x.toLowerCase() == t.toLowerCase()),
                              onSelected: (_) => _toggleTrait(t),
                              selectedColor: kBrandSubtle,
                              checkmarkColor: kTextBrand,
                            ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _traitCtrl,
                              textInputAction: TextInputAction.done,
                              onSubmitted: (_) => _addCustomTrait(),
                              decoration: const InputDecoration(
                                labelText: 'Add a trait',
                                isDense: true,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton(
                            onPressed: _addCustomTrait,
                            icon: const Icon(Icons.add_circle_outline,
                                color: kTextBrand),
                          ),
                        ],
                      ),
                    ]),
                    const SizedBox(height: 12),
                    _group('NOTES / DESCRIPTION', [
                      TextField(
                        controller: _descCtrl,
                        maxLines: 4,
                        decoration: const InputDecoration(
                          hintText:
                              'Scouting notes — playing style, strengths, role…',
                          alignLabelWithHint: true,
                        ),
                      ),
                    ]),
                  ],
                ),
    );
  }

  /// Common traits plus any custom ones already on the player.
  List<String> _traitOptions() {
    final opts = [..._kTraits];
    for (final t in _traits) {
      if (!opts.any((x) => x.toLowerCase() == t.toLowerCase())) opts.add(t);
    }
    return opts;
  }

  Widget _voiceCard() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kBrandSubtle,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kBrandBorder.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Describe this player',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kTextBrand)),
                const SizedBox(height: 2),
                Text(
                  _recording
                      ? 'Listening… tap to stop'
                      : 'Speak their positions, foot, height and strengths — AI fills the form.',
                  style: kStyleSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: _voiceBusy ? null : _toggleVoice,
            child: Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: _recording ? kRedFg : kBrand,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: (_recording ? kRedFg : kBrand).withValues(alpha: 0.25),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: _voiceBusy
                  ? const Padding(
                      padding: EdgeInsets.all(18),
                      child: CircularProgressIndicator(
                          color: Colors.white, strokeWidth: 2),
                    )
                  : Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded,
                      color: Colors.white, size: 26),
            ),
          ),
        ],
      ),
    );
  }

  Widget _group(String title, List<Widget> children) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceCard,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kBorderHairline, width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: kStyleLabel),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}
