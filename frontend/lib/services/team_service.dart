import 'package:flutter/foundation.dart';

import '../api/api.dart';
import '../models/team.dart';

/// App-wide team state: the user's teams and which one is currently selected.
///
/// A singleton (like [AuthService]) so any screen can read the current team and
/// react to switches. The selected team scopes the Players and Matches tabs.
class TeamService extends ChangeNotifier {
  TeamService._();

  static final TeamService instance = TeamService._();

  List<Team> _teams = const [];
  Team? _current;
  bool _loading = false;
  String? _error;

  List<Team> get teams => _teams;
  Team? get current => _current;
  int? get currentTeamId => _current?.id;
  bool get loading => _loading;
  String? get error => _error;
  bool get hasTeams => _teams.isNotEmpty;

  /// Load the user's teams. Keeps the current selection if it still exists,
  /// otherwise selects the first team.
  Future<void> load() async {
    _loading = true;
    _error = null;
    notifyListeners();
    try {
      final teams = await api.listTeams();
      _teams = teams;
      final keepId = _current?.id;
      _current = teams.isEmpty
          ? null
          : teams.firstWhere(
              (t) => t.id == keepId,
              orElse: () => teams.first,
            );
    } catch (e) {
      _error = e.toString();
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Switch the active team.
  void select(Team team) {
    if (_current?.id == team.id) return;
    _current = team;
    notifyListeners();
  }

  /// Create a new team, add it to the list, and make it current.
  Future<Team> createTeam(String name) async {
    final team = await api.createTeam(name);
    _teams = [..._teams, team];
    _current = team;
    notifyListeners();
    return team;
  }

  /// Join a shared team by code, add it to the list, and make it current.
  Future<Team> joinTeam(String code) async {
    final team = await api.joinTeam(code);
    if (!_teams.any((t) => t.id == team.id)) {
      _teams = [..._teams, team];
    }
    _current = team;
    notifyListeners();
    return team;
  }

  /// Rotate a team's join code (owner only) and update it in the list.
  Future<Team> refreshCode(int teamId) async {
    final updated = await api.refreshJoinCode(teamId);
    _teams = [for (final t in _teams) t.id == updated.id ? updated : t];
    if (_current?.id == updated.id) _current = updated;
    notifyListeners();
    return updated;
  }

  /// Delete a team (owner only), drop it from the list, and re-select another.
  Future<void> deleteTeam(int teamId) async {
    await api.deleteTeam(teamId);
    _teams = _teams.where((t) => t.id != teamId).toList();
    if (_current?.id == teamId) {
      _current = _teams.isEmpty ? null : _teams.first;
    }
    notifyListeners();
  }

  /// Reset on logout so the next user starts clean.
  void reset() {
    _teams = const [];
    _current = null;
    _error = null;
    _loading = false;
    notifyListeners();
  }
}
