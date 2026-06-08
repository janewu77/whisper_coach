import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_coach/models/import_review.dart';

void main() {
  group('ImportReview.fromJson', () {
    final json = {
      'session_id': 7,
      'team_id': 3,
      'status': 'pending',
      'reply': 'Merged Li Gang into 李刚',
      'new_players': [
        {'id': 1, 'name': 'Mike', 'number': 7, 'preferred_position': 'LW',
         'classification': 'new', 'deleted': false, 'changes': []},
      ],
      'updated_players': [
        {
          'id': 2, 'name': 'David', 'number': 10, 'preferred_position': 'CM',
          'classification': 'updated', 'deleted': false,
          'match_player_id': 20,
          'match': {'name': 'David', 'number': 8, 'preferred_position': 'CM'},
          'changes': [
            {'field': 'number', 'before': '8', 'after': '10'},
          ],
        },
      ],
      'duplicate_candidates': [
        {
          'id': 3, 'name': 'Li Gang', 'number': 5, 'preferred_position': 'RB',
          'classification': 'duplicate', 'confidence': 0.92, 'deleted': false,
          'match_player_id': 11,
          'match': {'name': '李刚', 'number': 11, 'preferred_position': 'RB'},
          'changes': [],
        },
      ],
      'unchanged_players': [
        {'id': 4, 'name': 'John', 'number': 9, 'preferred_position': 'ST',
         'classification': 'unchanged', 'deleted': false, 'changes': []},
      ],
    };

    test('parses sections and counts', () {
      final r = ImportReview.fromJson(json);
      expect(r.sessionId, 7);
      expect(r.reply, 'Merged Li Gang into 李刚');
      expect(r.newPlayers.single.name, 'Mike');
      expect(r.unchangedPlayers.single.name, 'John');
      // import writes everything except unchanged
      expect(r.importCount, 3);
      expect(r.totalCount, 4);
    });

    test('updated player exposes before/after change', () {
      final r = ImportReview.fromJson(json);
      final change = r.updatedPlayers.single.changes.single;
      expect(change.field, 'number');
      expect(change.label, 'Jersey Number');
      expect(change.before, '8');
      expect(change.after, '10');
    });

    test('duplicate exposes confidence percent and matched player', () {
      final r = ImportReview.fromJson(json);
      final dup = r.duplicateCandidates.single;
      expect(dup.confidencePercent, 92);
      expect(dup.match?.name, '李刚');
    });
  });
}
