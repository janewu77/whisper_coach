import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api.dart';
import '../api/client.dart';
import '../models/match.dart';
import '../models/player.dart';
import '../services/team_service.dart';
import '../theme.dart';
import '../widgets/squad_availability.dart';
import 'match_summary_screen.dart';

/// Read-only match details: fixture info, who is available, and the AI match
/// summary. Editing happens on [MatchEditScreen], reached from the Edit button
/// on the match card.
class MatchDetailScreen extends StatefulWidget {
  final Match match;

  const MatchDetailScreen({super.key, required this.match});

  @override
  State<MatchDetailScreen> createState() => _MatchDetailScreenState();
}

class _MatchDetailScreenState extends State<MatchDetailScreen> {
  Match get match => widget.match;

  // Squad availability for this match (same block as the lineup screen).
  List<Player>? _roster;
  final Set<int> _unavailable = {};

  @override
  void initState() {
    super.initState();
    _loadSquad();
  }

  /// Load the roster + availability (the stored per-match list wins;
  /// otherwise players whose absence covers the match date start out).
  Future<void> _loadSquad() async {
    try {
      final team = await api.getTeam(match.teamId);
      final unavail = <int>{};
      final stored = match.unavailablePlayerIds;
      if (stored != null) {
        unavail.addAll(stored);
      } else {
        final matchDate = DateTime.tryParse(match.date);
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
      // The availability block simply stays hidden when loading fails.
    }
  }

  Future<void> _toggleAvailability(Player p) async {
    final id = p.id;
    if (id == null) return;
    final wasOut = _unavailable.contains(id);
    setState(() => wasOut ? _unavailable.remove(id) : _unavailable.add(id));
    try {
      await api.updateMatch(
        match.id,
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

  void _openSummary() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => MatchSummaryScreen(
          matchId: match.id,
          opponent: match.opponent,
        ),
      ),
    );
  }

  String get _dateLabel {
    final parsed = DateTime.tryParse(match.date);
    return parsed == null
        ? match.date
        : DateFormat('EEE, d MMM yyyy').format(parsed);
  }

  String get _strengthLabel => switch (match.strength) {
        'strong' => 'Strong opponent',
        'weak' => 'Favourable',
        _ => 'Balanced',
      };

  @override
  Widget build(BuildContext context) {
    final ourTeam = TeamService.instance.current?.name ?? 'Our team';
    final home = match.isHome ? ourTeam : match.opponent;
    final away = match.isHome ? match.opponent : ourTeam;

    return Scaffold(
      backgroundColor: kSurfacePage,
      appBar: AppBar(
        title: const Text('Match details'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: kBorderHairline),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          // Fixture header.
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: kSurfaceCard,
              borderRadius: BorderRadius.circular(kRadiusCard),
              border: Border.all(color: kBorderHairline, width: 0.5),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 44,
                      height: 44,
                      decoration: BoxDecoration(
                        color: kBrandSubtle,
                        borderRadius: BorderRadius.circular(kRadiusInput),
                      ),
                      child: const Icon(Icons.sports_soccer_outlined,
                          color: kTextBrand, size: 22),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text.rich(
                        TextSpan(children: [
                          TextSpan(
                            text: home,
                            style: kStyleBody.copyWith(
                              fontSize: 16,
                              fontWeight: match.isHome
                                  ? FontWeight.w700
                                  : FontWeight.w400,
                              color: match.isHome
                                  ? kTextPrimary
                                  : kTextSecondary,
                            ),
                          ),
                          TextSpan(
                            text: '  vs  ',
                            style: kStyleSecondary.copyWith(fontSize: 13),
                          ),
                          TextSpan(
                            text: away,
                            style: kStyleBody.copyWith(
                              fontSize: 16,
                              fontWeight: match.isHome
                                  ? FontWeight.w400
                                  : FontWeight.w700,
                              color: match.isHome
                                  ? kTextSecondary
                                  : kTextPrimary,
                            ),
                          ),
                        ]),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: kSurfacePage,
                      borderRadius: BorderRadius.circular(100),
                    ),
                    child: Text(
                      '${match.isHome ? 'Home' : 'Away'} · $_strengthLabel',
                      style: kStyleLabel.copyWith(
                          fontSize: 11, letterSpacing: 0, color: kTextSecondary),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Detail rows (when & where) — before the squad.
          _InfoCard(rows: [
            _InfoRow(Icons.calendar_today_outlined, 'Date', _dateLabel),
            if (match.kickoffTime != null && match.kickoffTime!.isNotEmpty)
              _InfoRow(Icons.schedule_outlined, 'Kick-off', match.kickoffTime!),
            if (match.pitch != null && match.pitch!.isNotEmpty)
              _InfoRow(Icons.stadium_outlined, 'Pitch / ground', match.pitch!),
            if (match.address != null && match.address!.isNotEmpty)
              _InfoRow(Icons.location_on_outlined, 'Address', match.address!),
          ]),
          const SizedBox(height: 16),

          // Who can play this match (tap a player to move them).
          if (_roster != null) ...[
            Container(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
              decoration: BoxDecoration(
                color: kSurfaceCard,
                borderRadius: BorderRadius.circular(kRadiusCard),
                border: Border.all(color: kBorderHairline, width: 0.5),
              ),
              child: SquadAvailabilityBlock(
                roster: _roster!,
                unavailable: _unavailable,
                onToggle: _toggleAvailability,
                initiallyExpanded: true,
              ),
            ),
            const SizedBox(height: 16),
          ],

          // AI match report (formation, subs + detailed summary from notes).
          ElevatedButton.icon(
            onPressed: _openSummary,
            icon: const Icon(Icons.emoji_events_outlined, size: 18),
            label: const Text('Match summary'),
          ),

          if (match.notes != null && match.notes!.isNotEmpty) ...[
            const SizedBox(height: 16),
            const Text('NOTES', style: kStyleLabel),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: kSurfaceCard,
                borderRadius: BorderRadius.circular(kRadiusCard),
                border: Border.all(color: kBorderHairline, width: 0.5),
              ),
              child: Text(match.notes!, style: kStyleBody),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final List<_InfoRow> rows;
  const _InfoCard({required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: kSurfaceCard,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kBorderHairline, width: 0.5),
      ),
      child: Column(
        children: [
          for (var i = 0; i < rows.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: kBorderHairline),
            rows[i],
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(this.icon, this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: kTextTertiary),
          const SizedBox(width: 12),
          Text(label, style: kStyleSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: kStyleBody.copyWith(fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
