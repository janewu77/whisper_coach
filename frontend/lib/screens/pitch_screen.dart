import 'package:flutter/material.dart';
import '../api/api.dart';
import '../api/client.dart';
import '../models/lineup.dart';
import '../theme.dart';
import '../widgets/pitch_view.dart';
import '../main.dart';

class PitchScreen extends StatefulWidget {
  final PitchScreenArgs args;

  const PitchScreen({super.key, required this.args});

  @override
  State<PitchScreen> createState() => _PitchScreenState();
}

class _PitchScreenState extends State<PitchScreen> {
  late Lineup _lineup;
  bool _regenerating = false;
  String? _selectedPlayerId;

  @override
  void initState() {
    super.initState();
    _lineup = widget.args.lineup;
  }

  Future<void> _regenerate() async {
    setState(() => _regenerating = true);
    try {
      final newLineup = await api.generateLineup(
        widget.args.matchId,
        strength: widget.args.strength,
      );
      setState(() {
        _lineup = newLineup;
        _selectedPlayerId = null;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(dioErrorMessage(e))),
      );
    } finally {
      setState(() => _regenerating = false);
    }
  }

  void _onPlayerTap(PitchPlayer player) {
    setState(() {
      _selectedPlayerId =
          _selectedPlayerId == player.id ? null : player.id;
    });
  }

  void _startMatch() {
    Navigator.pushNamed(
      context,
      '/live',
      arguments: LiveScreenArgs(
        matchId: widget.args.matchId,
        opponent: widget.args.opponent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pitchPlayers = layoutFromLineup(_lineup);

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Lineup · ${_lineup.formation}'),
            Text(
              'vs ${widget.args.opponent}',
              style: kStyleSecondary,
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 12),
            padding:
                const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: kSurfaceInverse,
              borderRadius: BorderRadius.circular(100),
            ),
            child: const Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.memory_outlined,
                    size: 11, color: Colors.white),
                SizedBox(width: 4),
                Text(
                  'AI',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: kBorderHairline),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Formation chips
          _FormationChips(
            selected: _lineup.formation,
            onSelect: (f) {
              // Re-generate with same strength but we don't expose
              // a way to force a specific formation in this MVP.
              // Just show the currently selected one.
            },
          ),
          const SizedBox(height: 12),

          // Pitch
          PitchView(
            players: pitchPlayers,
            selectedId: _selectedPlayerId,
            onTap: _onPlayerTap,
          ),
          const SizedBox(height: 12),

          // AI reasoning card
          _ReasoningCard(reason: _lineup.reason),
          const SizedBox(height: 12),

          // Selected player info
          if (_selectedPlayerId != null) ...[
            _SelectedPlayerCard(
              player: pitchPlayers.firstWhere(
                (p) => p.id == _selectedPlayerId,
              ),
            ),
            const SizedBox(height: 12),
          ],

          // Actions row
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _regenerating ? null : _regenerate,
                  icon: _regenerating
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: kTextPrimary,
                          ),
                        )
                      : const Icon(Icons.refresh_outlined, size: 16),
                  label: Text(_regenerating ? 'Regenerating…' : 'Regenerate'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: ElevatedButton.icon(
                  onPressed: _startMatch,
                  icon: const Icon(Icons.play_arrow_outlined, size: 18),
                  label: const Text('Start match'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _FormationChips extends StatelessWidget {
  final String selected;
  final void Function(String) onSelect;

  const _FormationChips({required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const formations = ['4-3-3', '4-2-3-1', '3-5-2'];
    return Row(
      children: formations.map((f) {
        final isSelected = f == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: GestureDetector(
            onTap: () => onSelect(f),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 150),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? kBrandSubtle : kSurfaceCard,
                borderRadius: BorderRadius.circular(100),
                border: Border.all(
                  color: isSelected ? kBrandBorder : kBorderStrong,
                  width: isSelected ? 1.5 : 0.5,
                ),
              ),
              child: Text(
                f,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? kTextBrand : kTextPrimary,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ReasoningCard extends StatelessWidget {
  final String reason;

  const _ReasoningCard({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBrandSubtle,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kBrandBorder.withOpacity(0.5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.tips_and_updates_outlined,
                  size: 13, color: kTextBrand),
              SizedBox(width: 5),
              Text(
                'AI reasoning',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: kTextBrand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            reason,
            style: const TextStyle(
              fontSize: 13,
              color: kTextPrimary,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _SelectedPlayerCard extends StatelessWidget {
  final PitchPlayer player;

  const _SelectedPlayerCard({required this.player});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: kSurfaceCard,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kBorderHairline, width: 0.5),
      ),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: kBrand,
              border: Border.all(color: kBrandPressed, width: 2),
            ),
            child: Center(
              child: Text(
                player.initials,
                style: const TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w700,
                  color: kTextOnBrand,
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                player.initials,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: kTextPrimary,
                ),
              ),
              Text(
                player.position,
                style: const TextStyle(
                    fontSize: 12, color: kTextSecondary),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
