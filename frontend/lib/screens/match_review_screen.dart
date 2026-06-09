import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api.dart';
import '../api/client.dart';
import '../models/match.dart';
import '../theme.dart';

/// Review matches parsed from a photo/voice before saving. The coach edits the
/// list (opponent/date/location/strength), then Confirm creates them all.
class MatchReviewScreen extends StatefulWidget {
  final int teamId;
  final List<MatchDraft> drafts;

  const MatchReviewScreen({super.key, required this.teamId, required this.drafts});

  @override
  State<MatchReviewScreen> createState() => _MatchReviewScreenState();
}

class _MatchReviewScreenState extends State<MatchReviewScreen> {
  late final List<MatchDraft> _drafts;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _drafts = widget.drafts.isEmpty ? [MatchDraft()] : [...widget.drafts];
  }

  Future<void> _pickDate(MatchDraft d) async {
    final init = DateTime.tryParse(d.date ?? '') ?? DateTime.now();
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
      setState(() => d.date = DateFormat('yyyy-MM-dd').format(picked));
    }
  }

  Future<void> _confirm() async {
    final valid = _drafts.where((d) => d.opponent.trim().isNotEmpty).toList();
    if (valid.isEmpty) {
      _snack('Add at least one opponent.');
      return;
    }
    setState(() => _saving = true);
    try {
      for (final d in valid) {
        await api.createMatch(
          teamId: widget.teamId,
          opponent: d.opponent.trim(),
          location: (d.location?.trim().isNotEmpty ?? false)
              ? d.location!.trim()
              : 'TBD',
          date: d.date ?? DateFormat('yyyy-MM-dd').format(DateTime.now()),
          notes: d.notes,
          strength: d.strength,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        _snack(dioErrorMessage(e));
      }
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  int get _validCount =>
      _drafts.where((d) => d.opponent.trim().isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review matches'),
        bottom: PreferredSize(
          preferredSize: Size.fromHeight(_saving ? 2.5 : 0.5),
          child: _saving
              ? const LinearProgressIndicator(
                  minHeight: 2.5, color: kBrand, backgroundColor: kBrandSubtle)
              : Container(height: 0.5, color: kBorderHairline),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                Padding(
                  padding: const EdgeInsets.only(top: 6, bottom: 8),
                  child: Row(
                    children: [
                      const Icon(Icons.event_outlined,
                          size: 14, color: kTextSecondary),
                      const SizedBox(width: 6),
                      Text('MATCHES TO ADD · ${_drafts.length}',
                          style: kStyleLabel),
                    ],
                  ),
                ),
                for (var i = 0; i < _drafts.length; i++)
                  _draftCard(_drafts[i], i),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () => setState(() => _drafts.add(MatchDraft())),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add another match'),
                ),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Container(
              color: kSurfaceCard,
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: ElevatedButton.icon(
                onPressed: (_saving || _validCount == 0) ? null : _confirm,
                icon: const Icon(Icons.check_circle_outline, size: 18),
                label: Text('Confirm — add $_validCount '
                    '${_validCount == 1 ? 'match' : 'matches'}'),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _draftCard(MatchDraft d, int index) {
    final dateLabel = d.date == null
        ? 'Pick date'
        : DateFormat('EEE, d MMM yyyy').format(
            DateTime.tryParse(d.date!) ?? DateTime.now());
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
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
              Expanded(
                child: TextFormField(
                  initialValue: d.opponent,
                  decoration: const InputDecoration(labelText: 'Opponent *'),
                  onChanged: (v) => d.opponent = v,
                ),
              ),
              IconButton(
                tooltip: 'Remove',
                onPressed: () => setState(() => _drafts.removeAt(index)),
                icon: const Icon(Icons.close, size: 18, color: kTextTertiary),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () => _pickDate(d),
                  icon: const Icon(Icons.calendar_today_outlined, size: 15),
                  label: Text(dateLabel, overflow: TextOverflow.ellipsis),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  initialValue: d.location,
                  decoration: const InputDecoration(
                      labelText: 'Location', isDense: true),
                  onChanged: (v) => d.location = v,
                ),
              ),
            ],
          ),
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
                  selected: d.strength == s.$1,
                  onSelected: (_) => setState(() => d.strength = s.$1),
                  selectedColor: kBrandSubtle,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
