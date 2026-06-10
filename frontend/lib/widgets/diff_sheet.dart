import 'package:flutter/material.dart';

import '../theme.dart';

/// A single before → after change shown in the diff sheet.
class FieldDiff {
  final String label;
  final String before;
  final String after;
  final bool multiline;

  const FieldDiff(this.label, this.before, this.after, {this.multiline = false});
}

/// Show AI-proposed changes as a before/after bottom sheet.
/// Returns true (Apply) or null/false (Discard).
Future<bool?> showDiffSheet(
  BuildContext context,
  List<FieldDiff> diffs, {
  String title = 'Suggested changes',
  String subtitle = 'Review before applying.',
}) {
  return showModalBottomSheet<bool>(
    context: context,
    backgroundColor: kSurfaceCard,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(kRadiusSheet)),
    ),
    builder: (ctx) => _DiffSheet(diffs: diffs, title: title, subtitle: subtitle),
  );
}

class _DiffSheet extends StatelessWidget {
  final List<FieldDiff> diffs;
  final String title;
  final String subtitle;

  const _DiffSheet({
    required this.diffs,
    required this.title,
    required this.subtitle,
  });

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
            Text(title, style: kStyleScreenTitle),
            const SizedBox(height: 2),
            Text(subtitle, style: kStyleSecondary),
            const SizedBox(height: 14),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [for (final d in diffs) _DiffRow(diff: d)],
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
  final FieldDiff diff;

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
            _box(before, strike: true),
            const SizedBox(height: 4),
            _box(after, highlight: true),
          ] else
            Row(
              children: [
                Flexible(child: _box(before, strike: true)),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Icon(Icons.arrow_forward, size: 14, color: kTextTertiary),
                ),
                Flexible(child: _box(after, highlight: true)),
              ],
            ),
        ],
      ),
    );
  }

  Widget _box(String text, {bool strike = false, bool highlight = false}) {
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
          decoration:
              strike && text != '—' ? TextDecoration.lineThrough : null,
        ),
      ),
    );
  }
}
