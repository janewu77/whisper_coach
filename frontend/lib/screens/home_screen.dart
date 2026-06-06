import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import '../api/api.dart';
import '../api/client.dart';
import '../models/player.dart';
import '../theme.dart';
import '../widgets/player_chip.dart';
import '../main.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ── Upload & roster state ────────────────────────────────────────────────
  XFile? _photoFile;
  Uint8List? _photoBytes;
  int? _teamId;
  List<Player> _players = [];
  bool _extracting = false;

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

  Future<void> _pickAndExtract() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    final bytes = await picked.readAsBytes();
    setState(() {
      _photoFile = picked;
      _photoBytes = bytes;
      _extracting = true;
      _players = [];
      _teamId = null;
    });
    try {
      final result = await api.extractRoster(picked);
      setState(() {
        _teamId = result.teamId;
        _players = result.players;
      });
    } catch (e) {
      _showError(dioErrorMessage(e));
    } finally {
      setState(() => _extracting = false);
    }
  }

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
    if (_teamId == null) {
      _showError('Upload a team photo first.');
      return;
    }
    if (_opponentCtrl.text.trim().isEmpty) {
      _showError('Enter the opponent name.');
      return;
    }
    setState(() => _generating = true);
    try {
      final match = await api.createMatch(
        teamId: _teamId!,
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
      setState(() => _generating = false);
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
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/images/whisper_coach_logo.png',
              width: 30,
              height: 30,
            ),
            const SizedBox(width: 10),
            const Text('New match'),
          ],
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: kBorderHairline),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _UploadZone(
            photoBytes: _photoBytes,
            extracting: _extracting,
            onTap: _pickAndExtract,
          ),
          const SizedBox(height: 16),

          // Detected players
          if (_extracting)
            const Center(child: CircularProgressIndicator(color: kBrand))
          else if (_players.isNotEmpty) ...[
            const Text('DETECTED PLAYERS', style: kStyleLabel),
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: _players
                  .map((p) => PlayerChip(name: p.name))
                  .toList(),
            ),
            const SizedBox(height: 16),
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

class _UploadZone extends StatelessWidget {
  final Uint8List? photoBytes;
  final bool extracting;
  final VoidCallback onTap;

  const _UploadZone({
    required this.photoBytes,
    required this.extracting,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: kBrandSubtle,
          borderRadius: BorderRadius.circular(kRadiusCard),
          border: Border.all(
            color: kBrandBorder.withOpacity(0.6),
            width: 1,
            strokeAlign: BorderSide.strokeAlignInside,
          ),
        ),
        child: photoBytes != null
            ? ClipRRect(
                borderRadius: BorderRadius.circular(kRadiusCard - 1),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.memory(photoBytes!, fit: BoxFit.cover),
                    Container(color: Colors.black26),
                    if (extracting)
                      const Center(
                        child: CircularProgressIndicator(color: Colors.white),
                      )
                    else
                      Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: const Text(
                            'Tap to replace',
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          ),
                        ),
                      ),
                  ],
                ),
              )
            : Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.upload_file_outlined,
                      size: 28, color: kTextBrand),
                  const SizedBox(height: 6),
                  Text(
                    'Upload team roster photo',
                    style: kStyleBody.copyWith(
                      color: kTextBrand,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'AI will extract player names automatically',
                    style: kStyleSecondary,
                  ),
                ],
              ),
      ),
    );
  }
}

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
