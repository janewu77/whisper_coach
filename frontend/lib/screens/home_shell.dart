import 'package:flutter/material.dart';

import '../models/team.dart';
import '../services/team_service.dart';
import '../theme.dart';
import 'create_team_screen.dart';
import 'matches_tab.dart';
import 'players_tab.dart';
import 'profile_tab.dart';

/// The main authenticated app: a team selector in the header plus the bottom
/// tab bar (Players, Matches). More tabs can be added to [_tabs] later.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  static const _menuCreate = -1;

  Future<void> _onMenuSelected(int value) async {
    if (value == _menuCreate) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const CreateTeamScreen()),
      );
      return;
    }
    final team =
        TeamService.instance.teams.firstWhere((t) => t.id == value);
    TeamService.instance.select(team);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: TeamService.instance,
      builder: (context, _) {
        final teamId = TeamService.instance.currentTeamId;
        final current = TeamService.instance.current;
        final tabs = <Widget>[
          teamId == null ? const SizedBox.shrink() : PlayersTab(teamId: teamId),
          teamId == null ? const SizedBox.shrink() : MatchesTab(teamId: teamId),
          const ProfileTab(),
        ];

        return Scaffold(
          appBar: AppBar(
            titleSpacing: 12,
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Image.asset(
                  'assets/images/whisper_coach_logo.png',
                  width: 28,
                  height: 28,
                ),
                const SizedBox(width: 10),
                const Text('Whisper Coach'),
              ],
            ),
            actions: [
              _TeamSelector(
                current: current,
                teams: TeamService.instance.teams,
                onSelected: _onMenuSelected,
              ),
              const SizedBox(width: 8),
            ],
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(0.5),
              child: Container(height: 0.5, color: kBorderHairline),
            ),
          ),
          body: IndexedStack(index: _index, children: tabs),
          bottomNavigationBar: BottomNavigationBar(
            currentIndex: _index,
            onTap: (i) => setState(() => _index = i),
            items: const [
              BottomNavigationBarItem(
                icon: Icon(Icons.groups_2_outlined),
                activeIcon: Icon(Icons.groups_2),
                label: 'Players',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.sports_soccer_outlined),
                activeIcon: Icon(Icons.sports_soccer),
                label: 'Matches',
              ),
              BottomNavigationBarItem(
                icon: Icon(Icons.person_outline),
                activeIcon: Icon(Icons.person),
                label: 'Profile',
              ),
            ],
          ),
        );
      },
    );
  }
}

/// The pull-down team picker shown in the app-bar title.
class _TeamSelector extends StatelessWidget {
  final Team? current;
  final List<Team> teams;
  final ValueChanged<int> onSelected;

  const _TeamSelector({
    required this.current,
    required this.teams,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<int>(
      tooltip: 'Switch team',
      offset: const Offset(0, 44),
      onSelected: onSelected,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
      ),
      itemBuilder: (context) => [
        for (final t in teams)
          PopupMenuItem<int>(
            value: t.id,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    t.name,
                    overflow: TextOverflow.ellipsis,
                    style: kStyleBody.copyWith(
                      fontWeight: t.id == current?.id
                          ? FontWeight.w600
                          : FontWeight.w400,
                    ),
                  ),
                ),
                if (t.id == current?.id)
                  const Icon(Icons.check, size: 18, color: kBrand),
              ],
            ),
          ),
        const PopupMenuDivider(),
        PopupMenuItem<int>(
          value: _HomeShellState._menuCreate,
          child: Row(
            children: [
              const Icon(Icons.add, size: 18, color: kTextBrand),
              const SizedBox(width: 8),
              Text('Create new team…',
                  style: kStyleBody.copyWith(color: kTextBrand)),
            ],
          ),
        ),
      ],
      child: Container(
        constraints: const BoxConstraints(maxWidth: 180),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: kSurfacePage,
          borderRadius: BorderRadius.circular(100),
          border: Border.all(color: kBorderHairline, width: 0.5),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.groups_2_outlined, size: 16, color: kTextSecondary),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                current?.name ?? 'Team',
                overflow: TextOverflow.ellipsis,
                style: kStyleBody.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
            const Icon(Icons.expand_more, size: 18, color: kTextSecondary),
          ],
        ),
      ),
    );
  }
}
