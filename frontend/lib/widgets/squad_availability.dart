import 'package:flutter/material.dart';

import '../models/player.dart';
import '../theme.dart';

/// Collapsible per-match squad availability: a one-line header with counts,
/// expanding to tappable AVAILABLE / NOT AVAILABLE chip rows. The parent owns
/// the `unavailable` set and persists changes in [onToggle].
class SquadAvailabilityBlock extends StatefulWidget {
  final List<Player> roster;
  final Set<int> unavailable;
  final void Function(Player) onToggle;
  final bool initiallyExpanded;

  const SquadAvailabilityBlock({
    super.key,
    required this.roster,
    required this.unavailable,
    required this.onToggle,
    this.initiallyExpanded = false,
  });

  @override
  State<SquadAvailabilityBlock> createState() => _SquadAvailabilityBlockState();
}

class _SquadAvailabilityBlockState extends State<SquadAvailabilityBlock> {
  late bool _expanded = widget.initiallyExpanded;

  /// Short display name: nickname, else first name + last-name initial.
  static String _shortName(Player p) {
    if (p.nickname != null && p.nickname!.isNotEmpty) return p.nickname!;
    final parts = p.name.trim().split(RegExp(r'\s+'));
    if (parts.length < 2) return p.name;
    return '${parts.first} ${parts.last[0]}.';
  }

  Widget _row({
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
                  onTap: () => widget.onToggle(p),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      color: out ? kRedBg : kBrandSubtle,
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: out
                            ? kRedFg.withValues(alpha: 0.3)
                            : kBrandBorder,
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
    final roster = widget.roster;
    final unavailable = widget.unavailable;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () => setState(() => _expanded = !_expanded),
          borderRadius: BorderRadius.circular(6),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Icons.groups_2_outlined,
                    size: 14, color: kTextSecondary),
                const SizedBox(width: 6),
                Text(
                  'SQUAD · ${roster.length - unavailable.length} available'
                  '${unavailable.isNotEmpty ? ' · ${unavailable.length} out' : ''}',
                  style: kStyleLabel,
                ),
                const Spacer(),
                Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more,
                  size: 18,
                  color: kTextSecondary,
                ),
              ],
            ),
          ),
        ),
        if (_expanded) ...[
          const SizedBox(height: 8),
          _row(
            title: 'AVAILABLE',
            players:
                roster.where((p) => !unavailable.contains(p.id)).toList(),
            out: false,
          ),
          const SizedBox(height: 10),
          _row(
            title: 'NOT AVAILABLE',
            players:
                roster.where((p) => unavailable.contains(p.id)).toList(),
            out: true,
          ),
        ],
      ],
    );
  }
}
