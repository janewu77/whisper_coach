import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/api.dart';
import '../api/client.dart';
import '../main.dart';
import '../models/match.dart';
import '../theme.dart';

class MatchListScreen extends StatefulWidget {
  final Api? apiClient;

  const MatchListScreen({super.key, this.apiClient});

  @override
  State<MatchListScreen> createState() => _MatchListScreenState();
}

class _MatchListScreenState extends State<MatchListScreen> {
  late Future<List<Match>> _matches;
  final Set<int> _openingMatchIds = {};

  Api get _api => widget.apiClient ?? api;

  @override
  void initState() {
    super.initState();
    _matches = _api.listMatches();
  }

  Future<void> _refresh() async {
    final matches = _api.listMatches();
    setState(() => _matches = matches);
    await matches;
  }

  Future<void> _openMatch(Match match) async {
    if (_openingMatchIds.contains(match.id)) return;
    setState(() => _openingMatchIds.add(match.id));

    try {
      final details = await _api.getMatch(match.id);
      final lineup = details.lineup ??
          await _api.generateLineup(
            match.id,
            strength: match.strength,
          );
      if (!mounted) return;
      await Navigator.pushNamed(
        context,
        '/pitch',
        arguments: PitchScreenArgs(
          matchId: match.id,
          opponent: match.opponent,
          lineup: lineup,
          strength: match.strength,
        ),
      );
      if (mounted) await _refresh();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() => _openingMatchIds.remove(match.id));
      }
    }
  }

  Future<void> _createMatch() async {
    await Navigator.pushNamed(context, '/new');
    if (mounted) await _refresh();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Matches'),
        actions: [
          IconButton(
            tooltip: 'Refresh matches',
            onPressed: _refresh,
            icon: const Icon(Icons.refresh_outlined),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: kBorderHairline),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _createMatch,
        backgroundColor: kBrand,
        foregroundColor: kTextOnBrand,
        elevation: 0,
        icon: const Icon(Icons.add, size: 20),
        label: const Text('New match'),
      ),
      body: FutureBuilder<List<Match>>(
        future: _matches,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: kBrand),
            );
          }

          if (snapshot.hasError) {
            return _MessageState(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load matches',
              message: dioErrorMessage(snapshot.error!),
              actionLabel: 'Try again',
              onAction: _refresh,
            );
          }

          final matches = snapshot.data ?? const [];
          if (matches.isEmpty) {
            return _MessageState(
              icon: Icons.sports_soccer_outlined,
              title: 'No matches yet',
              message: 'Create your first match to generate a lineup.',
              actionLabel: 'Create match',
              onAction: _createMatch,
            );
          }

          return RefreshIndicator(
            color: kBrand,
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: matches.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final match = matches[index];
                return _MatchCard(
                  match: match,
                  opening: _openingMatchIds.contains(match.id),
                  onTap: () => _openMatch(match),
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _MatchCard extends StatelessWidget {
  final Match match;
  final bool opening;
  final VoidCallback onTap;

  const _MatchCard({
    required this.match,
    required this.opening,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final parsedDate = DateTime.tryParse(match.date);
    final dateLabel = parsedDate == null
        ? match.date
        : DateFormat('EEE, d MMM yyyy').format(parsedDate);
    final strengthLabel = switch (match.strength) {
      'strong' => 'Strong opponent',
      'weak' => 'Favourable',
      _ => 'Balanced',
    };

    return Material(
      color: kSurfaceCard,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
        side: const BorderSide(color: kBorderHairline, width: 0.5),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: opening ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: kBrandSubtle,
                  borderRadius: BorderRadius.circular(kRadiusInput),
                ),
                child: const Icon(
                  Icons.sports_soccer_outlined,
                  color: kTextBrand,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'vs ${match.opponent}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kStyleBody.copyWith(
                        fontSize: 15,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$dateLabel · ${match.location}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: kStyleSecondary,
                    ),
                    const SizedBox(height: 7),
                    _StrengthBadge(label: strengthLabel),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              if (opening)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: kBrand,
                  ),
                )
              else
                const Icon(
                  Icons.chevron_right,
                  color: kTextTertiary,
                  size: 22,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StrengthBadge extends StatelessWidget {
  final String label;

  const _StrengthBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: kSurfacePage,
        borderRadius: BorderRadius.circular(100),
      ),
      child: Text(
        label,
        style: kStyleLabel.copyWith(
          fontSize: 10,
          letterSpacing: 0,
          color: kTextSecondary,
        ),
      ),
    );
  }
}

class _MessageState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _MessageState({
    required this.icon,
    required this.title,
    required this.message,
    required this.actionLabel,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 56,
              height: 56,
              decoration: const BoxDecoration(
                color: kBrandSubtle,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: kTextBrand, size: 28),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: kStyleScreenTitle,
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: kStyleSecondary,
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: 160,
              child: ElevatedButton(
                onPressed: onAction,
                child: Text(actionLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
