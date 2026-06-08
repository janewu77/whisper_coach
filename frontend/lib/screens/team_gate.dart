import 'package:flutter/material.dart';

import '../api/client.dart';
import '../services/team_service.dart';
import '../theme.dart';
import 'create_team_screen.dart';
import 'home_shell.dart';

/// Shown once the user is authenticated. Loads their teams, then routes to the
/// first-run "create team" screen (no teams) or the main [HomeShell].
class TeamGate extends StatefulWidget {
  const TeamGate({super.key});

  @override
  State<TeamGate> createState() => _TeamGateState();
}

class _TeamGateState extends State<TeamGate> {
  @override
  void initState() {
    super.initState();
    // Kick off the load now so `loading` is already true on the first build
    // (avoids a flash of the create-team screen before the request starts).
    TeamService.instance.load();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TeamService.instance,
      builder: (context, _) {
        final svc = TeamService.instance;

        if (svc.loading && !svc.hasTeams) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator(color: kBrand)),
          );
        }

        if (svc.error != null && !svc.hasTeams) {
          return Scaffold(
            body: Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.cloud_off_outlined,
                        color: kTextTertiary, size: 40),
                    const SizedBox(height: 12),
                    Text(
                      'Could not load your teams',
                      style: kStyleScreenTitle,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      dioErrorMessage(svc.error!),
                      style: kStyleSecondary,
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: 160,
                      child: ElevatedButton(
                        onPressed: () => TeamService.instance.load(),
                        child: const Text('Try again'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }

        if (!svc.hasTeams) {
          return const CreateTeamScreen(firstRun: true);
        }

        return const HomeShell();
      },
    );
  }
}
