import 'package:flutter/material.dart';

import '../api/client.dart';
import '../services/team_service.dart';
import '../theme.dart';

/// Create a team by name. Shown by [TeamGate] on first run (no team yet) and
/// also pushed as a route from the team selector ("Create new team…").
class CreateTeamScreen extends StatefulWidget {
  /// When true, this is the first-run experience (no teams yet) and the intro
  /// copy is shown. When false it's a plain "add another team" form.
  final bool firstRun;

  const CreateTeamScreen({super.key, this.firstRun = false});

  @override
  State<CreateTeamScreen> createState() => _CreateTeamScreenState();
}

class _CreateTeamScreenState extends State<CreateTeamScreen> {
  final _nameCtrl = TextEditingController();
  bool _creating = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      _showError('Enter a team name.');
      return;
    }
    setState(() => _creating = true);
    try {
      await TeamService.instance.createTeam(name);
      if (!mounted) return;
      // When pushed as a route, pop back; on first run the TeamGate swaps us
      // out automatically once a team exists.
      if (Navigator.of(context).canPop()) Navigator.of(context).pop();
    } catch (e) {
      _showError(dioErrorMessage(e));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.firstRun ? 'Create your team' : 'New team'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(0.5),
          child: Container(height: 0.5, color: kBorderHairline),
        ),
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.firstRun) ...[
                  Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: const BoxDecoration(
                      color: kBrandSubtle,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.groups_2_outlined,
                        color: kTextBrand, size: 30),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Set up your first team',
                    textAlign: TextAlign.center,
                    style: kStyleScreenTitle,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Give your team a name to get started. You can add players '
                    'and create matches next.',
                    textAlign: TextAlign.center,
                    style: kStyleSecondary,
                  ),
                  const SizedBox(height: 24),
                ],
                TextField(
                  controller: _nameCtrl,
                  autofocus: true,
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _create(),
                  decoration: const InputDecoration(
                    labelText: 'Team name *',
                    hintText: 'e.g. Sunday FC',
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: _creating ? null : _create,
                  icon: _creating
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            color: Colors.white,
                            strokeWidth: 2,
                          ),
                        )
                      : const Icon(Icons.check, size: 18),
                  label: Text(_creating ? 'Creating…' : 'Create team'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
