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
import 'crop_screen.dart';

/// Edit an existing match. The coach can fill the fields by photo or voice
/// (parsed by the match extractor) and then Save.
class MatchDetailScreen extends StatefulWidget {
  final Match match;

  const MatchDetailScreen({super.key, required this.match});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  final _opponentCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String _date = '';
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
    _locationCtrl.text = m.location;
    _date = m.date;
    _strength = m.strength;
    _notesCtrl.text = m.notes ?? '';
  }

  @override
  void dispose() {
    _opponentCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _applyDraft(MatchDraft d) {
    setState(() {
      if (d.opponent.trim().isNotEmpty) _opponentCtrl.text = d.opponent.trim();
      if (d.location != null && d.location!.isNotEmpty) {
        _locationCtrl.text = d.location!;
      }
      if (d.date != null && d.date!.isNotEmpty) _date = d.date!;
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
      if (drafts.isNotEmpty) _applyDraft(drafts.first);
      _snack(drafts.isEmpty ? 'Nothing recognised.' : 'Filled from photo — review and Save.');
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
      if (drafts.isNotEmpty) _applyDraft(drafts.first);
      _snack(drafts.isEmpty ? 'Nothing recognised.' : 'Filled from voice — review and Save.');
    } catch (e) {
      _snack(dioErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
        location: _locationCtrl.text.trim().isEmpty
            ? 'TBD'
            : _locationCtrl.text.trim(),
        date: _date,
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
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: kBorderHairline),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _fillCard(),
          const SizedBox(height: 14),
          TextField(
            controller: _opponentCtrl,
            decoration: const InputDecoration(labelText: 'Opponent *'),
          ),
          const SizedBox(height: 10),
          InkWell(
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
          const SizedBox(height: 10),
          TextField(
            controller: _locationCtrl,
            decoration: const InputDecoration(labelText: 'Location'),
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

  Widget _fillCard() {
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
                const Text('Fill from photo or voice',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: kTextBrand)),
                const SizedBox(height: 2),
                Text(
                  _recording
                      ? 'Listening… tap to stop'
                      : 'Snap a fixture or say the match details — AI fills the form.',
                  style: kStyleSecondary,
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(10),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(color: kBrand, strokeWidth: 2),
              ),
            )
          else ...[
            IconButton(
              tooltip: 'From photo',
              onPressed: _fillFromPhoto,
              icon: const Icon(Icons.photo_camera_back_outlined, color: kTextBrand),
            ),
            GestureDetector(
              onTap: _toggleVoice,
              child: Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _recording ? kRedFg : kBrand,
                  shape: BoxShape.circle,
                ),
                child: Icon(_recording ? Icons.stop_rounded : Icons.mic_rounded,
                    color: Colors.white, size: 22),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
