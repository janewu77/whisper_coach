import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../api/api.dart';
import '../api/client.dart';
import '../models/team.dart';
import '../theme.dart';

/// Roster view for the currently selected team. Players can be added by
/// uploading a team photo (AI extraction appends them to this team).
class PlayersTab extends StatefulWidget {
  final int teamId;

  const PlayersTab({super.key, required this.teamId});

  @override
  State<PlayersTab> createState() => _PlayersTabState();
}

class _PlayersTabState extends State<PlayersTab> {
  late Future<Team> _team;
  bool _extracting = false;

  @override
  void initState() {
    super.initState();
    _team = api.getTeam(widget.teamId);
  }

  @override
  void didUpdateWidget(PlayersTab old) {
    super.didUpdateWidget(old);
    if (old.teamId != widget.teamId) {
      _team = api.getTeam(widget.teamId);
    }
  }

  Future<void> _refresh() async {
    final team = api.getTeam(widget.teamId);
    setState(() => _team = team);
    await team;
  }

  Future<void> _addFromPhoto() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked == null) return;
    setState(() => _extracting = true);
    try {
      await api.extractRoster(picked, teamId: widget.teamId);
      await _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(dioErrorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _extracting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kSurfacePage,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _extracting ? null : _addFromPhoto,
        backgroundColor: kBrand,
        foregroundColor: kTextOnBrand,
        elevation: 0,
        icon: _extracting
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    color: Colors.white, strokeWidth: 2),
              )
            : const Icon(Icons.add_a_photo_outlined, size: 20),
        label: Text(_extracting ? 'Reading photo…' : 'Add from photo'),
      ),
      body: FutureBuilder<Team>(
        future: _team,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: kBrand));
          }
          if (snapshot.hasError) {
            return _Message(
              icon: Icons.cloud_off_outlined,
              title: 'Could not load players',
              message: dioErrorMessage(snapshot.error!),
              actionLabel: 'Try again',
              onAction: _refresh,
            );
          }
          final players = snapshot.data?.players ?? const [];
          if (players.isEmpty) {
            return _Message(
              icon: Icons.person_add_alt_outlined,
              title: 'No players yet',
              message:
                  'Upload a team photo and AI will extract the player names.',
              actionLabel: 'Add from photo',
              onAction: _addFromPhoto,
            );
          }
          return RefreshIndicator(
            color: kBrand,
            onRefresh: _refresh,
            child: ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: players.length + 1,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '${players.length} '
                      '${players.length == 1 ? 'PLAYER' : 'PLAYERS'}',
                      style: kStyleLabel,
                    ),
                  );
                }
                final p = players[index - 1];
                return _PlayerTile(
                  name: p.name,
                  number: p.number,
                  position: p.preferredPosition,
                );
              },
            ),
          );
        },
      ),
    );
  }
}

class _PlayerTile extends StatelessWidget {
  final String name;
  final int? number;
  final String? position;

  const _PlayerTile({required this.name, this.number, this.position});

  @override
  Widget build(BuildContext context) {
    final subtitle = [
      if (position != null && position!.isNotEmpty) position!,
    ].join(' · ');
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
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
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: kBrandSubtle,
              borderRadius: BorderRadius.circular(kRadiusInput),
            ),
            child: Text(
              number?.toString() ?? '–',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: kTextBrand,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: kStyleBody.copyWith(fontWeight: FontWeight.w500),
                ),
                if (subtitle.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(subtitle, style: kStyleSecondary),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String title;
  final String message;
  final String actionLabel;
  final VoidCallback onAction;

  const _Message({
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
            Text(title, textAlign: TextAlign.center, style: kStyleScreenTitle),
            const SizedBox(height: 6),
            Text(message, textAlign: TextAlign.center, style: kStyleSecondary),
            const SizedBox(height: 20),
            SizedBox(
              width: 180,
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
