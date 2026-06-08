import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show XFile;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api/api.dart';
import '../api/client.dart';
import '../models/import_review.dart';
import '../theme.dart';

/// Review an OCR/AI roster import before it touches the database. Players are
/// grouped into New / Updated / Duplicate / Unchanged sections; the coach can
/// edit, delete or merge each one (by hand or via a natural-language / voice
/// command) and only "Confirm Import" writes to the real roster.
class ImportReviewScreen extends StatefulWidget {
  final ImportReview review;

  const ImportReviewScreen({super.key, required this.review});

  @override
  State<ImportReviewScreen> createState() => _ImportReviewScreenState();
}

class _ImportReviewScreenState extends State<ImportReviewScreen> {
  late ImportReview _review;
  final _commandCtrl = TextEditingController();
  final _recorder = AudioRecorder();

  bool _busy = false;
  bool _recording = false;
  bool _togglingRecording = false;
  String _recordingFilename = 'command.m4a';
  String _recordingMimeType = 'audio/mp4';
  String? _recordingPath;

  int get _sessionId => _review.sessionId;

  @override
  void initState() {
    super.initState();
    _review = widget.review;
  }

  @override
  void dispose() {
    _commandCtrl.dispose();
    _recorder.dispose();
    super.dispose();
  }

  // ── Shared call wrapper ────────────────────────────────────────────────────

  Future<void> _apply(Future<ImportReview> future, {String? toast}) async {
    setState(() => _busy = true);
    try {
      final review = await future;
      if (!mounted) return;
      setState(() => _review = review);
      final msg = review.reply ?? toast;
      if (msg != null && msg.isNotEmpty) _toast(msg);
    } catch (e) {
      if (mounted) _toast(dioErrorMessage(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  // ── Item actions ───────────────────────────────────────────────────────────

  Future<void> _edit(ImportItem item) async {
    final result = await showDialog<_EditResult>(
      context: context,
      builder: (_) => _EditDialog(item: item),
    );
    if (result == null) return;
    await _apply(
      api.editImportItem(
        _sessionId,
        item.id,
        name: result.name,
        number: result.number,
        preferredPosition: result.position,
      ),
    );
  }

  Future<void> _delete(ImportItem item) async {
    final ok = await _confirm(
      title: 'Remove ${item.name}?',
      message: 'This player will be excluded from the import.',
      action: 'Remove',
      destructive: true,
    );
    if (ok != true) return;
    await _apply(api.deleteImportItem(_sessionId, item.id));
  }

  Future<void> _merge(ImportItem item) async {
    if (item.matchPlayerId == null) return;
    final existing = item.match?.name ?? 'existing player';
    final ok = await _confirm(
      title: 'Merge players?',
      message: 'Treat "${item.name}" as the existing "$existing" and update it.',
      action: 'Merge',
    );
    if (ok != true) return;
    await _apply(
      api.mergeImportItem(_sessionId, item.id, targetPlayerId: item.matchPlayerId),
      toast: 'Merged into $existing',
    );
  }

  Future<bool?> _confirm({
    required String title,
    required String message,
    required String action,
    bool destructive = false,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: destructive
                ? ElevatedButton.styleFrom(backgroundColor: kRedFg)
                : null,
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(action),
          ),
        ],
      ),
    );
  }

  // ── Commands (text + voice) ────────────────────────────────────────────────

  Future<void> _sendTextCommand() async {
    final text = _commandCtrl.text.trim();
    if (text.isEmpty) return;
    _commandCtrl.clear();
    await _apply(api.sendImportCommand(_sessionId, text));
  }

  Future<void> _toggleRecording() async {
    if (_togglingRecording || _busy) return;
    _togglingRecording = true;
    try {
      if (_recording) {
        await _stopRecording();
      } else {
        await _startRecording();
      }
    } catch (e) {
      if (mounted) _toast('Recording error: $e');
    } finally {
      _togglingRecording = false;
    }
  }

  Future<void> _startRecording() async {
    if (!await _recorder.hasPermission()) {
      _toast('Microphone permission denied.');
      return;
    }
    final ts = DateTime.now().millisecondsSinceEpoch;
    late final RecordConfig config;
    if (kIsWeb) {
      if (await _recorder.isEncoderSupported(AudioEncoder.opus)) {
        config = const RecordConfig(encoder: AudioEncoder.opus);
        _recordingFilename = 'cmd_$ts.webm';
        _recordingMimeType = 'audio/webm';
      } else {
        config = const RecordConfig(encoder: AudioEncoder.aacLc);
        _recordingFilename = 'cmd_$ts.m4a';
        _recordingMimeType = 'audio/mp4';
      }
      _recordingPath = '';
    } else {
      final dir = await getTemporaryDirectory();
      _recordingFilename = 'cmd_$ts.m4a';
      _recordingMimeType = 'audio/mp4';
      _recordingPath = '${dir.path}/$_recordingFilename';
      config = const RecordConfig(encoder: AudioEncoder.aacLc);
    }
    await _recorder.start(config, path: _recordingPath!);
    if (mounted) setState(() => _recording = true);
  }

  Future<void> _stopRecording() async {
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() => _recording = false);
    if (path == null) return;
    final file = XFile(path, name: _recordingFilename, mimeType: _recordingMimeType);
    await _apply(api.sendImportVoiceCommand(_sessionId, file));
  }

  // ── Confirm ────────────────────────────────────────────────────────────────

  Future<void> _confirmImport() async {
    final ok = await _confirm(
      title: 'Confirm import?',
      message:
          '${_review.importCount} player(s) will be saved to your roster. '
          'Unchanged players are skipped.',
      action: 'Confirm',
    );
    if (ok != true) return;
    setState(() => _busy = true);
    try {
      final res = await api.confirmImport(_sessionId);
      if (!mounted) return;
      _toast(
        'Imported: ${res.created} new, ${res.updated} updated'
        '${res.skipped > 0 ? ', ${res.skipped} unchanged' : ''}.',
      );
      Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        _toast(dioErrorMessage(e));
        setState(() => _busy = false);
      }
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final r = _review;
    final empty = r.totalCount == 0;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review import'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_busy ? 2.5 : 0.5),
          child: _busy
              ? const LinearProgressIndicator(
                  minHeight: 2.5, color: kBrand, backgroundColor: kBrandSubtle)
              : Container(height: 0.5, color: kBorderHairline),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: empty
                ? const _EmptyState()
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                    children: [
                      _ReviewBanner(review: r),
                      _Section(
                        title: 'New Players',
                        icon: Icons.person_add_alt_1_outlined,
                        items: r.newPlayers,
                        builder: _itemCard,
                      ),
                      _Section(
                        title: 'Updated Players',
                        icon: Icons.edit_outlined,
                        items: r.updatedPlayers,
                        builder: _itemCard,
                      ),
                      _Section(
                        title: 'Duplicate Candidates',
                        icon: Icons.merge_type_outlined,
                        items: r.duplicateCandidates,
                        builder: _itemCard,
                      ),
                      _Section(
                        title: 'Unchanged Players',
                        icon: Icons.check_circle_outline,
                        items: r.unchangedPlayers,
                        builder: _itemCard,
                      ),
                    ],
                  ),
          ),
          _buildCommandBar(),
          _buildConfirmBar(),
        ],
      ),
    );
  }

  Widget _itemCard(ImportItem item) => _ImportItemCard(
        item: item,
        busy: _busy,
        onEdit: () => _edit(item),
        onDelete: () => _delete(item),
        onMerge: item.classification == 'duplicate' ? () => _merge(item) : null,
      );

  Widget _buildCommandBar() {
    return Container(
      decoration: const BoxDecoration(
        color: kSurfaceCard,
        border: Border(top: BorderSide(color: kBorderHairline, width: 0.5)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: TextField(
              controller: _commandCtrl,
              enabled: !_busy && !_recording,
              textInputAction: TextInputAction.send,
              onSubmitted: (_) => _sendTextCommand(),
              decoration: InputDecoration(
                isDense: true,
                hintText: _recording
                    ? 'Listening… tap stop'
                    : 'e.g. "Change Wang Wu\'s number to 15"',
              ),
            ),
          ),
          const SizedBox(width: 8),
          _CircleButton(
            icon: _recording ? Icons.stop_rounded : Icons.mic_none_rounded,
            color: _recording ? kRedFg : kBrand,
            onTap: _busy ? null : _toggleRecording,
          ),
          const SizedBox(width: 6),
          _CircleButton(
            icon: Icons.send_rounded,
            color: kBrand,
            onTap: (_busy || _recording) ? null : _sendTextCommand,
          ),
        ],
      ),
    );
  }

  Widget _buildConfirmBar() {
    return SafeArea(
      top: false,
      child: Container(
        color: kSurfaceCard,
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
        child: ElevatedButton.icon(
          onPressed: (_busy || _review.importCount == 0) ? null : _confirmImport,
          icon: const Icon(Icons.check_circle_outline, size: 18),
          label: Text('Confirm Import (${_review.importCount})'),
        ),
      ),
    );
  }
}

// ── Banner ────────────────────────────────────────────────────────────────────

class _ReviewBanner extends StatelessWidget {
  final ImportReview review;
  const _ReviewBanner({required this.review});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBrandSubtle,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kBrandBorder.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        children: [
          const Icon(Icons.fact_check_outlined, color: kTextBrand, size: 18),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Review the extracted players. Nothing is saved until you confirm.',
              style: kStyleSecondary.copyWith(color: kTextBrand),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Section ─────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<ImportItem> items;
  final Widget Function(ImportItem) builder;

  const _Section({
    required this.title,
    required this.icon,
    required this.items,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 6, bottom: 8),
          child: Row(
            children: [
              Icon(icon, size: 14, color: kTextSecondary),
              const SizedBox(width: 6),
              Text('${title.toUpperCase()} · ${items.length}', style: kStyleLabel),
            ],
          ),
        ),
        ...items.map(
          (it) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: builder(it),
          ),
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}

// ── Item card ─────────────────────────────────────────────────────────────────

class _ImportItemCard extends StatelessWidget {
  final ImportItem item;
  final bool busy;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onMerge;

  const _ImportItemCard({
    required this.item,
    required this.busy,
    required this.onEdit,
    required this.onDelete,
    this.onMerge,
  });

  @override
  Widget build(BuildContext context) {
    final isDuplicate = item.classification == 'duplicate';
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
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: kBrandSubtle,
                  borderRadius: BorderRadius.circular(kRadiusInput),
                ),
                child: Text(
                  item.number?.toString() ?? '–',
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: kTextBrand,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: kStyleBody.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (item.preferredPosition != null &&
                        item.preferredPosition!.isNotEmpty)
                      Text(item.preferredPosition!, style: kStyleSecondary),
                  ],
                ),
              ),
            ],
          ),

          // Duplicate candidate match + confidence
          if (isDuplicate && item.match != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: kAmberBg,
                borderRadius: BorderRadius.circular(kRadiusInput),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.name}  ↔  ${item.match!.name}',
                      style: kStyleBodyMd.copyWith(color: kAmberFg),
                    ),
                  ),
                  if (item.confidencePercent != null)
                    Text(
                      '${item.confidencePercent}%',
                      style: kStyleBodyMd.copyWith(
                        color: kAmberFg,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
            ),
          ],

          // Updated: before/after for each changed field
          if (item.changes.isNotEmpty) ...[
            const SizedBox(height: 8),
            ...item.changes.map((c) => _ChangeRow(change: c)),
          ],

          // Actions
          const SizedBox(height: 6),
          Row(
            children: [
              _ActionButton(
                icon: Icons.edit_outlined,
                label: 'Edit',
                onTap: busy ? null : onEdit,
              ),
              if (onMerge != null)
                _ActionButton(
                  icon: Icons.merge_type_outlined,
                  label: 'Merge',
                  onTap: busy ? null : onMerge,
                  emphasis: true,
                ),
              _ActionButton(
                icon: Icons.delete_outline,
                label: 'Delete',
                onTap: busy ? null : onDelete,
                destructive: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ChangeRow extends StatelessWidget {
  final FieldChange change;
  const _ChangeRow({required this.change});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text('${change.label}:', style: kStyleSecondary),
          ),
          Text(change.before ?? '—', style: kStyleBodyMd.copyWith(color: kTextTertiary)),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 6),
            child: Icon(Icons.arrow_forward, size: 12, color: kTextTertiary),
          ),
          Text(
            change.after ?? '—',
            style: kStyleBodyMd.copyWith(
              color: kTextBrand,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool destructive;
  final bool emphasis;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.destructive = false,
    this.emphasis = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = destructive
        ? kRedFg
        : emphasis
            ? kTextBrand
            : kTextSecondary;
    return TextButton.icon(
      onPressed: onTap,
      style: TextButton.styleFrom(
        foregroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      icon: Icon(icon, size: 16),
      label: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _CircleButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const _CircleButton({required this.icon, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: enabled ? color : kBorderStrong,
          borderRadius: BorderRadius.circular(kRadiusInput),
        ),
        child: Icon(icon, color: Colors.white, size: 20),
      ),
    );
  }
}

// ── Edit dialog ───────────────────────────────────────────────────────────────

class _EditResult {
  final String name;
  final int? number;
  final String? position;
  const _EditResult({required this.name, this.number, this.position});
}

class _EditDialog extends StatefulWidget {
  final ImportItem item;
  const _EditDialog({required this.item});

  @override
  State<_EditDialog> createState() => _EditDialogState();
}

class _EditDialogState extends State<_EditDialog> {
  late final TextEditingController _name =
      TextEditingController(text: widget.item.name);
  late final TextEditingController _number =
      TextEditingController(text: widget.item.number?.toString() ?? '');
  late final TextEditingController _position =
      TextEditingController(text: widget.item.preferredPosition ?? '');

  @override
  void dispose() {
    _name.dispose();
    _number.dispose();
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit player'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _number,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Jersey number'),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _position,
            decoration: const InputDecoration(labelText: 'Position'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            final name = _name.text.trim();
            if (name.isEmpty) return;
            Navigator.pop(
              context,
              _EditResult(
                name: name,
                number: int.tryParse(_number.text.trim()),
                position:
                    _position.text.trim().isEmpty ? null : _position.text.trim(),
              ),
            );
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.search_off_outlined, size: 44, color: kTextTertiary),
            SizedBox(height: 12),
            Text('No players detected', style: kStyleScreenTitle),
            SizedBox(height: 6),
            Text(
              'The photo didn\'t yield any players. Go back and try another image.',
              textAlign: TextAlign.center,
              style: kStyleSecondary,
            ),
          ],
        ),
      ),
    );
  }
}
