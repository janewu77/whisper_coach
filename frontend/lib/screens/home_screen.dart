import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../api/api.dart';
import '../api/client.dart';
import '../services/team_service.dart';
import '../theme.dart';
import '../main.dart';

/// Create a new match for the currently selected team and generate a lineup.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Match form ───────────────────────────────────────────────────────────
  final _opponentCtrl = TextEditingController();
  final _locationCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _strength; // 'strong' | 'weak' | null

  DateTime _matchDate = DateTime.now();

  // ── Loading ──────────────────────────────────────────────────────────────
  bool _generating = false;

  @override
  void dispose() {
    _opponentCtrl.dispose();
    _locationCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  // ── Actions ──────────────────────────────────────────────────────────────

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _matchDate,
      firstDate: DateTime.now().subtract(const Duration(days: 30)),
      lastDate: DateTime.now().add(const Duration(days: 90)),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme:
              Theme.of(ctx).colorScheme.copyWith(primary: kBrand),
        ),
        child: child!,
      ),
    );
    if (picked != null) setState(() => _matchDate = picked);
  }

  Future<void> _generateLineup() async {
    final teamId = TeamService.instance.currentTeamId;
    if (teamId == null) {
      _showError('Select a team first.');
      return;
    }
    if (_opponentCtrl.text.trim().isEmpty) {
      _showError('Enter the opponent name.');
      return;
    }
    setState(() => _generating = true);
    try {
      final match = await api.createMatch(
        teamId: teamId,
        opponent: _opponentCtrl.text.trim(),
        location: _locationCtrl.text.trim().isEmpty
            ? 'TBD'
            : _locationCtrl.text.trim(),
        date: DateFormat('yyyy-MM-dd').format(_matchDate),
        notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
        strength: _strength,
      );
      final lineup = await api.generateLineup(
        match.id,
        strength: _strength,
      );
      if (!mounted) return;
      Navigator.pushReplacementNamed(
        context,
        '/pitch',
        arguments: PitchScreenArgs(
          matchId: match.id,
          opponent: match.opponent,
          lineup: lineup,
          strength: _strength,
        ),
      );
    } catch (e) {
      _showError(dioErrorMessage(e));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg)),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final teamName = TeamService.instance.current?.name;
    return Scaffold(
      appBar: AppBar(
        title: const Text('New match'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: kBorderHairline),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (teamName != null) ...[
            Row(
              children: [
                const Icon(Icons.groups_2_outlined,
                    size: 16, color: kTextSecondary),
                const SizedBox(width: 6),
                Text('Team: $teamName', style: kStyleSecondary),
              ],
            ),
            const SizedBox(height: 12),
          ],

          // Match details card
          _card(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  controller: _opponentCtrl,
                  decoration:
                      const InputDecoration(labelText: 'Opponent *'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _locationCtrl,
                  decoration: const InputDecoration(
                      labelText: 'Location', hintText: 'Home / Away / Ground name'),
                ),
                const SizedBox(height: 10),
                // Date picker row
                InkWell(
                  onTap: _pickDate,
                  borderRadius: BorderRadius.circular(kRadiusInput),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Date',
                      suffixIcon: Icon(Icons.calendar_today_outlined,
                          size: 16, color: kTextTertiary),
                    ),
                    child: Text(
                      DateFormat('EEEE, d MMMM yyyy').format(_matchDate),
                      style: kStyleBody,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _notesCtrl,
                  maxLines: 2,
                  decoration: const InputDecoration(
                    labelText: 'Match notes (optional)',
                    hintText: 'Tactics, key players to watch…',
                    alignLabelWithHint: true,
                  ),
                ),
                const SizedBox(height: 12),
                // Strength selector
                const Text('OPPONENT STRENGTH', style: kStyleLabel),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  children: [
                    _StrengthChip(
                      label: 'Balanced',
                      value: null,
                      selected: _strength == null,
                      onTap: () => setState(() => _strength = null),
                    ),
                    _StrengthChip(
                      label: 'Strong',
                      value: 'strong',
                      selected: _strength == 'strong',
                      onTap: () => setState(() => _strength = 'strong'),
                    ),
                    _StrengthChip(
                      label: 'Weak',
                      value: 'weak',
                      selected: _strength == 'weak',
                      onTap: () => setState(() => _strength = 'weak'),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // CTA
          ElevatedButton.icon(
            onPressed: _generating ? null : _generateLineup,
            icon: _generating
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.auto_fix_high_outlined, size: 18),
            label:
                Text(_generating ? 'Generating…' : 'Generate lineup'),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }

  Widget _card({required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: kSurfaceCard,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kBorderHairline, width: 0.5),
      ),
      child: child,
    );
  }
}

// ── Sub-widgets ───────────────────────────────────────────────────────────────

class _StrengthChip extends StatelessWidget {
  final String label;
  final String? value;
  final bool selected;
  final VoidCallback onTap;

  const _StrengthChip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? kBrandSubtle : kSurfaceCard,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: selected ? kBrandBorder : kBorderStrong,
            width: selected ? 1 : 0.5,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: selected ? kTextBrand : kTextPrimary,
          ),
        ),
      ),
    );
  }
}
