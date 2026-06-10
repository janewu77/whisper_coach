import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api/api.dart';
import '../api/client.dart';
import '../models/match.dart';
import '../theme.dart';
import '../widgets/diff_sheet.dart';
import 'crop_screen.dart';

/// Edit an existing match. The coach can fill the fields by photo or voice
/// (parsed by the match extractor) and then Save.
class MatchEditScreen extends StatefulWidget {
  final Match match;

  const MatchEditScreen({super.key, required this.match});

  @override
  State<MatchEditScreen> createState() => _MatchEditScreenState();
}

class _MatchEditScreenState extends State<MatchEditScreen> {
  final _opponentCtrl = TextEditingController();
  final _pitchCtrl = TextEditingController();
  final _addressCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _date = '';
  String? _kickoff; // "HH:MM"
  bool _isHome = true;
  String? _strength;

  bool _saving = false;
  bool _busy = false; // extracting from photo/voice

  final _recorder = AudioRecorder();
  bool _recording = false;
  String _recFilename = 'match.m4a';
  String _recMime = 'audio/mp4';
  String? _recPath;

  @override
  void initState() {
    super.initState();
    final m = widget.match;
    _opponentCtrl.text = m.opponent;
    _pitchCtrl.text = m.pitch ?? '';
    _addressCtrl.text = m.address ?? '';
    _isHome = m.isHome;
    _date = m.date;
    _kickoff = m.kickoffTime;
    _strength = m.strength;
    _notesCtrl.text = m.notes ?? '';
  }

  @override
  void dispose() {
    _opponentCtrl.dispose();
    _pitchCtrl.dispose();
    _addressCtrl.dispose();
    _notesCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _applyDraft(MatchDraft d) {
    setState(() {
      if (d.opponent.trim().isNotEmpty) _opponentCtrl.text = d.opponent.trim();
      _isHome = d.isHome;
      if (d.pitch != null && d.pitch!.isNotEmpty) _pitchCtrl.text = d.pitch!;
      if (d.address != null && d.address!.isNotEmpty) {
        _addressCtrl.text = d.address!;
      }
      if (d.date != null && d.date!.isNotEmpty) _date = d.date!;
      if (d.kickoffTime != null && d.kickoffTime!.isNotEmpty) {
        _kickoff = d.kickoffTime;
      }
      if (d.strength != null) _strength = d.strength;
      if (d.notes != null && d.notes!.isNotEmpty) _notesCtrl.text = d.notes!;
    });
  }

  Future<void> _fillFromPhoto() async {
    final picked =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    if (!mounted) return;
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(builder: (_) => CropScreen(bytes: bytes)),
    );
    if (cropped == null) return;
    final file = XFile.fromData(
      cropped,
      name: 'match_crop.jpg',
      mimeType: 'image/jpeg',
    );
    setState(() => _busy = true);
    try {
      final drafts = await api.extractMatches(widget.match.teamId, file);
      if (mounted) setState(() => _busy = false);
      if (drafts.isEmpty) {
        _snack('Nothing recognised.');
      } else {
        await _reviewProposal(drafts.first);
      }
    } catch (e) {
      _snack(dioErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _toggleVoice() async {
    if (_busy) return;
    try {
      if (_recording) {
        await _stopVoice();
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
        _recFilename = 'match_$ts.webm';
        _recMime = 'audio/webm';
      } else {
        config = const RecordConfig(encoder: AudioEncoder.aacLc);
        _recFilename = 'match_$ts.m4a';
        _recMime = 'audio/mp4';
      }
      _recPath = '';
    } else {
      final dir = await getTemporaryDirectory();
      _recFilename = 'match_$ts.m4a';
      _recMime = 'audio/mp4';
      _recPath = '${dir.path}/$_recFilename';
      config = const RecordConfig(encoder: AudioEncoder.aacLc);
    }
    await _recorder.start(config, path: _recPath!);
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _stopVoice() async {
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
      final drafts =
          await api.extractMatchesVoice(widget.match.teamId, file);
      if (mounted) setState(() => _busy = false);
      if (drafts.isEmpty) {
        _snack('Nothing recognised.');
      } else {
        await _reviewProposal(drafts.first);
      }
    } catch (e) {
      _snack(dioErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // ── Diff + confirm ───────────────────────────────────────────────────────

  String _strengthLabel(String? s) => switch (s) {
        'strong' => 'Strong',
        'weak' => 'Weak',
        _ => 'Balanced',
      };

  Future<void> _reviewProposal(MatchDraft p) async {
    final diffs = <FieldDiff>[];
    void add(String label, String before, String after, {bool ml = false}) {
      if (before.trim() != after.trim()) {
        diffs.add(FieldDiff(label, before, after, multiline: ml));
      }
    }

    if (p.opponent.trim().isNotEmpty) {
      add('Opponent', _opponentCtrl.text.trim(), p.opponent.trim());
    }
    add('Home / Away', _isHome ? 'Home' : 'Away', p.isHome ? 'Home' : 'Away');
    if (p.date != null && p.date!.isNotEmpty) add('Date', _date, p.date!);
    if (p.kickoffTime != null && p.kickoffTime!.isNotEmpty) {
      add('Time', _kickoff ?? '', p.kickoffTime!);
    }
    if (p.pitch != null && p.pitch!.isNotEmpty) {
      add('Pitch', _pitchCtrl.text.trim(), p.pitch!);
    }
    if (p.address != null && p.address!.isNotEmpty) {
      add('Address', _addressCtrl.text.trim(), p.address!);
    }
    if (p.strength != null) {
      add('Strength', _strengthLabel(_strength), _strengthLabel(p.strength));
    }
    if (p.notes != null && p.notes!.isNotEmpty) {
      add('Notes', _notesCtrl.text.trim(), p.notes!, ml: true);
    }

    if (diffs.isEmpty) {
      _snack('No changes suggested.');
      return;
    }
    final apply = await showDiffSheet(context, diffs,
        subtitle: 'From your photo/voice — review before applying.');
    if (apply == true) _applyDraft(p);
  }

  Future<void> _pickDate() async {
    final init = DateTime.tryParse(_date) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: init,
      firstDate: DateTime.now().subtract(const Duration(days: 60)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: Theme.of(ctx).colorScheme.copyWith(primary: kBrand),
        ),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _date = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _pickTime() async {
    final parts = (_kickoff ?? '').split(':');
    final init = parts.length == 2
        ? TimeOfDay(
            hour: int.tryParse(parts[0]) ?? 15,
            minute: int.tryParse(parts[1]) ?? 0)
        : const TimeOfDay(hour: 15, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: init);
    if (picked != null) {
      setState(() => _kickoff =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    }
  }

  Future<void> _save() async {
    if (_opponentCtrl.text.trim().isEmpty) {
      _snack('Enter the opponent.');
      return;
    }
    setState(() => _saving = true);
    try {
      await api.updateMatch(
        widget.match.id,
        opponent: _opponentCtrl.text.trim(),
        isHome: _isHome,
        pitch: _pitchCtrl.text.trim(),
        address: _addressCtrl.text.trim(),
        date: _date,
        kickoffTime: _kickoff ?? '',
        notes: _notesCtrl.text.trim(),
        strength: _strength,
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
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dateLabel = _date.isEmpty
        ? 'Pick date'
        : DateFormat('EEE, d MMM yyyy')
            .format(DateTime.tryParse(_date) ?? DateTime.now());
    return Scaffold(
      floatingActionButton: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          FloatingActionButton(
            heroTag: 'matchFillVoice',
            onPressed: _busy ? null : _toggleVoice,
            backgroundColor: _recording ? kRedFg : kBrand,
            foregroundColor: kTextOnBrand,
            elevation: 0,
            shape: const CircleBorder(),
            tooltip: _recording ? 'Stop & review' : 'Fill by voice',
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
          FloatingActionButton(
            heroTag: 'matchFillPhoto',
            onPressed: (_busy || _recording) ? null : _fillFromPhoto,
            backgroundColor: kBrand,
            foregroundColor: kTextOnBrand,
            elevation: 0,
            shape: const CircleBorder(),
            tooltip: 'Fill from photo',
            child: (_busy && !_recording)
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
        title: const Text('Edit match'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(color: kBrand, strokeWidth: 2),
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
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          Text(
            _recording
                ? 'Listening… tap the stop button (bottom right).'
                : 'Tap the photo or mic in the bottom right to fill from a '
                    'fixture photo or your voice — review before applying.',
            style: kStyleSecondary,
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _opponentCtrl,
            decoration: const InputDecoration(labelText: 'Opponent *'),
          ),
          const SizedBox(height: 12),
          const Text('OUR TEAM PLAYS', style: kStyleLabel),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              ChoiceChip(
                label: const Text('Home'),
                selected: _isHome,
                onSelected: (_) => setState(() => _isHome = true),
                selectedColor: kBrandSubtle,
              ),
              ChoiceChip(
                label: const Text('Away'),
                selected: !_isHome,
                onSelected: (_) => setState(() => _isHome = false),
                selectedColor: kBrandSubtle,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(kRadiusInput),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      suffixIcon: Icon(Icons.calendar_today_outlined,
                          size: 16, color: kTextTertiary),
                    ),
                    child: Text(dateLabel, style: kStyleBody),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 110,
                child: InkWell(
                  onTap: _pickTime,
                  borderRadius: BorderRadius.circular(kRadiusInput),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Time',
                      suffixIcon: Icon(Icons.schedule_outlined,
                          size: 16, color: kTextTertiary),
                    ),
                    child: Text(_kickoff ?? '--:--', style: kStyleBody),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _pitchCtrl,
            decoration: const InputDecoration(labelText: 'Pitch / ground'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _addressCtrl,
            decoration: const InputDecoration(labelText: 'Address'),
          ),
          const SizedBox(height: 14),
          const Text('OPPONENT STRENGTH', style: kStyleLabel),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final s in const [
                (null, 'Balanced'),
                ('strong', 'Strong'),
                ('weak', 'Weak'),
              ])
                ChoiceChip(
                  label: Text(s.$2),
                  selected: _strength == s.$1,
                  onSelected: (_) => setState(() => _strength = s.$1),
                  selectedColor: kBrandSubtle,
                ),
            ],
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _notesCtrl,
            maxLines: 2,
            decoration: const InputDecoration(
              labelText: 'Match notes (optional)',
              alignLabelWithHint: true,
            ),
          ),
        ],
      ),
    );
  }

}
