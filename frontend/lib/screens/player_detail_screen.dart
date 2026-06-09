import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api/api.dart';
import '../api/client.dart';
import '../models/player.dart';
import '../theme.dart';
import 'crop_screen.dart';

// Positions laid out like a formation board: first line = attackers,
// last line = goalkeeper.
const _kPositionLines = [
  ['LW', 'ST', 'RW'], // attackers
  ['CAM'], // attacking midfield
  ['LM', 'CM', 'RM'], // midfield
  ['CDM'], // defensive midfield
  ['LWB', 'RWB'], // wing backs
  ['LB', 'CB', 'RB'], // defenders
  ['GK'], // goalkeeper
];

const _kTraits = [
  'Strong', 'Fast', 'Good ball control', 'Good passing', 'Good finishing',
  'Good vision', 'Stamina', 'Aerial', 'Leadership', 'Tackling', 'Composure',
];

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
  final List<Absence> _absences = [];
  bool _leftFoot = false;
  bool _rightFoot = false;

  bool _loading = true;
  bool _saving = false;
  String? _loadError;

  // Voice / photo profiling.
  final _recorder = AudioRecorder();
  bool _recording = false;
  bool _voiceBusy = false;
  bool _photoBusy = false;
  bool get _busy => _voiceBusy || _photoBusy;
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
    if (replaceName) {
      _nameCtrl.text = p.name;
      // Absences are managed only here (not in the voice profile), so load
      // them once on initial fetch and never let a describe-merge clear them.
      _absences
        ..clear()
        ..addAll(p.absences);
    }
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
    if (p.preferredFoot != null) {
      _leftFoot = p.preferredFoot == 'left' || p.preferredFoot == 'both';
      _rightFoot = p.preferredFoot == 'right' || p.preferredFoot == 'both';
    }
    if (p.description != null && p.description!.isNotEmpty) {
      _descCtrl.text = p.description!;
    }
  }

  /// Map the two foot toggles back to the stored value (both → "both").
  String? _footValue() {
    if (_leftFoot && _rightFoot) return 'both';
    if (_leftFoot) return 'left';
    if (_rightFoot) return 'right';
    return null;
  }

  static String _footLabel(String? code) => switch (code) {
        'left' => 'Left',
        'right' => 'Right',
        'both' => 'Left & Right',
        _ => '',
      };

  // ── Voice describe ───────────────────────────────────────────────────────

  Future<void> _fillFromPhoto() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => CropScreen(bytes: bytes)),
    );
    if (cropped == null) return;
    final file = XFile.fromData(
      cropped,
      name: 'player_crop.jpg',
      mimeType: 'image/jpeg',
    );
    setState(() => _photoBusy = true);
    try {
      final p = await api.describePlayerPhoto(
        widget.teamId,
        widget.playerId,
        file,
      );
      if (!mounted) return;
      setState(() => _photoBusy = false);
      await _reviewProposal(p);
    } catch (e) {
      if (mounted) {
        setState(() => _photoBusy = false);
        _snack(dioErrorMessage(e));
      }
    }
  }

  Future<void> _toggleVoice() async {
    if (_voiceBusy || _photoBusy) return;
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
      setState(() => _voiceBusy = false);
      // Don't apply directly — show the proposed changes for confirmation.
      await _reviewProposal(p);
    } catch (e) {
      if (mounted) {
        setState(() => _voiceBusy = false);
        _snack(dioErrorMessage(e));
      }
    }
  }

  /// Show the LLM's proposed profile as a before/after diff; apply to the form
  /// only if the coach confirms (they can still edit fields before Save).
  Future<void> _reviewProposal(Player proposed) async {
    final diffs = _computeDiffs(proposed);
    if (diffs.isEmpty) {
      _snack('No changes suggested.');
      return;
    }
    final apply = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: kSurfaceCard,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
      ),
      builder: (ctx) => _ProposalSheet(diffs: diffs),
    );
    if (apply == true) setState(() => _applyPlayer(proposed));
  }

  List<_FieldDiff> _computeDiffs(Player p) {
    final diffs = <_FieldDiff>[];
    void add(String label, String before, String after, {bool multiline = false}) {
      if (before.trim() != after.trim()) {
        diffs.add(_FieldDiff(label, before, after, multiline: multiline));
      }
    }

    add('Jersey number', _numberCtrl.text.trim(),
        p.number?.toString() ?? '');
    add('Positions', _positions.join(', '), p.positions.join(', '));
    add('Preferred foot', _footLabel(_footValue()), _footLabel(p.preferredFoot));
    add('Height', _heightCtrl.text.trim(),
        p.heightCm != null ? '${p.heightCm} cm' : '');
    add('Traits', _traits.join(', '), p.traits.join(', '));
    add('Description', _descCtrl.text.trim(), p.description ?? '',
        multiline: true);
    return diffs;
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
        preferredFoot: _footValue(),
        heightCm: int.tryParse(_heightCtrl.text.trim()),
        traits: _traits,
        description: _descCtrl.text.trim(),
        absences: _absences,
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

  Future<void> _addAbsence(String kind) async {
    final now = DateTime.now();
    final range = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 2),
      initialDateRange: DateTimeRange(start: now, end: now),
      helpText: kind == 'injury' ? 'Injury period' : 'Vacation period',
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: kBrand),
        ),
        child: child!,
      ),
    );
    if (range == null) return;
    setState(() => _absences.add(Absence(
          kind: kind,
          from: DateUtils.dateOnly(range.start),
          to: DateUtils.dateOnly(range.end),
        )));
  }

  // ── Build ──────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      floatingActionButton: (_loading || _loadError != null)
          ? null
          : Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'playerFillVoice',
                  onPressed: _photoBusy ? null : _toggleVoice,
                  backgroundColor: _recording ? kRedFg : kBrand,
                  foregroundColor: kTextOnBrand,
                  elevation: 0,
                  shape: const CircleBorder(),
                  tooltip: _recording ? 'Stop & review' : 'Fill by voice',
                  child: _voiceBusy
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                              color: Colors.white, strokeWidth: 2),
                        )
                      : Icon(
                          _recording
                              ? Icons.stop_rounded
                              : Icons.mic_none_outlined,
                          size: 22),
                ),
                const SizedBox(width: 12),
                FloatingActionButton(
                  heroTag: 'playerFillPhoto',
                  onPressed: _busy || _recording ? null : _fillFromPhoto,
                  backgroundColor: kBrand,
                  foregroundColor: kTextOnBrand,
                  elevation: 0,
                  shape: const CircleBorder(),
                  tooltip: 'Fill from photo',
                  child: _photoBusy
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
          preferredSize: Size.fromHeight(_busy ? 2.5 : 0.5),
          child: _busy
              ? const LinearProgressIndicator(
                  minHeight: 2.5, color: kBrand, backgroundColor: kBrandSubtle)
              : Container(height: 0.5, color: kBorderHairline),
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
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
                  children: [
                    Text(
                      _recording
                          ? 'Listening… tap the stop button (bottom right).'
                          : 'Tap the photo or mic in the bottom right to fill '
                              'the profile — review the changes before saving.',
                      style: kStyleSecondary,
                    ),
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
                      Text('Attackers at the top → goalkeeper at the bottom.',
                          style: kStyleSecondary),
                      const SizedBox(height: 10),
                      for (final line in _kPositionLines)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: SizedBox(
                            width: double.infinity,
                            child: Wrap(
                              alignment: WrapAlignment.center,
                              spacing: 8,
                              runSpacing: 8,
                              children: line
                                  .map((c) => FilterChip(
                                        label: Text(c),
                                        selected: _positions.contains(c),
                                        onSelected: (_) => _togglePosition(c),
                                        selectedColor: kBrandSubtle,
                                        checkmarkColor: kTextBrand,
                                      ))
                                  .toList(),
                            ),
                          ),
                        ),
                    ]),
                    const SizedBox(height: 12),
                    _group('PHYSICAL', [
                      const Text('Preferred foot', style: kStyleSecondary),
                      const SizedBox(height: 8),
                      Wrap(
                        spacing: 8,
                        children: [
                          FilterChip(
                            label: const Text('Left'),
                            selected: _leftFoot,
                            onSelected: (v) => setState(() => _leftFoot = v),
                            selectedColor: kBrandSubtle,
                            checkmarkColor: kTextBrand,
                          ),
                          FilterChip(
                            label: const Text('Right'),
                            selected: _rightFoot,
                            onSelected: (v) => setState(() => _rightFoot = v),
                            selectedColor: kBrandSubtle,
                            checkmarkColor: kTextBrand,
                          ),
                        ],
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
                    const SizedBox(height: 12),
                    _group('AVAILABILITY', [
                      Text(
                        'Injury or vacation periods — used to show whether the '
                        'player is available today / for the next match.',
                        style: kStyleSecondary,
                      ),
                      const SizedBox(height: 10),
                      if (_absences.isEmpty)
                        Text('No absences — available.',
                            style: kStyleSecondary.copyWith(color: kGreenFg)),
                      for (var i = 0; i < _absences.length; i++)
                        _absenceRow(_absences[i], i),
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _addAbsence('injury'),
                              icon: const Icon(Icons.healing_outlined, size: 16),
                              label: const Text('Add injury'),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _addAbsence('vacation'),
                              icon: const Icon(Icons.beach_access_outlined,
                                  size: 16),
                              label: const Text('Add vacation'),
                            ),
                          ),
                        ],
                      ),
                    ]),
                  ],
                ),
    );
  }

  Widget _absenceRow(Absence a, int index) {
    final fmt = DateFormat('d MMM yyyy');
    final injury = a.kind == 'injury';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(injury ? Icons.healing_outlined : Icons.beach_access_outlined,
              size: 18, color: injury ? kRedFg : kAmberFg),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(injury ? 'Injury' : 'Vacation',
                    style: kStyleBody.copyWith(fontWeight: FontWeight.w500)),
                Text('${fmt.format(a.from)} – ${fmt.format(a.to)}',
                    style: kStyleSecondary),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            visualDensity: VisualDensity.compact,
            onPressed: () => setState(() => _absences.removeAt(index)),
            icon: const Icon(Icons.close, size: 18, color: kTextTertiary),
          ),
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

class _FieldDiff {
  final String label;
  final String before;
  final String after;
  final bool multiline;

  const _FieldDiff(this.label, this.before, this.after, {this.multiline = false});
}

/// Bottom sheet showing the LLM's proposed profile changes as before → after.
/// Returns true (Apply) or null/false (Discard).
class _ProposalSheet extends StatelessWidget {
  final List<_FieldDiff> diffs;

  const _ProposalSheet({required this.diffs});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                decoration: BoxDecoration(
                  color: kBorderStrong,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            const Text('Suggested changes', style: kStyleScreenTitle),
            const SizedBox(height: 2),
            Text('From your description — review before applying.',
                style: kStyleSecondary),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final d in diffs) _DiffRow(diff: d),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text('Discard'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(context, true),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Apply'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DiffRow extends StatelessWidget {
  final _FieldDiff diff;

  const _DiffRow({required this.diff});

  @override
  Widget build(BuildContext context) {
    final before = diff.before.isEmpty ? '—' : diff.before;
    final after = diff.after.isEmpty ? '—' : diff.after;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(diff.label.toUpperCase(), style: kStyleLabel),
          const SizedBox(height: 4),
          if (diff.multiline) ...[
            _valueBox(before, strike: true),
            const SizedBox(height: 4),
            _valueBox(after, highlight: true),
          ] else
            Row(
              children: [
                Flexible(child: _valueBox(before, strike: true)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 14, color: kTextTertiary),
                ),
                Flexible(child: _valueBox(after, highlight: true)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _valueBox(String text, {bool strike = false, bool highlight = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: highlight ? kBrandSubtle : kSurfacePage,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 13,
          height: 1.4,
          color: highlight ? kTextBrand : kTextSecondary,
          decoration: strike && text != '—' ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}
