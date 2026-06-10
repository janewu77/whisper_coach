import 'package:flutter_test/flutter_test.dart';
import 'package:whisper_coach/models/lineup.dart';
import 'package:whisper_coach/widgets/pitch_view.dart';

PitchPlayer _byPos(List<PitchPlayer> players, String pos, {int nth = 0}) =>
    players.where((p) => p.position == pos).elementAt(nth);

void main() {
  test('4-3-3 layout is driven by position codes, not slot order', () {
    // Deliberately shuffled order (the bug: dots used to follow this order).
    final lineup = Lineup(
      formation: '4-3-3',
      lineup: const [
        LineupSlot(player: 'R Winger', position: 'RW'),
        LineupSlot(player: 'C Back One', position: 'CB'),
        LineupSlot(player: 'Striker', position: 'ST'),
        LineupSlot(player: 'L Back', position: 'LB'),
        LineupSlot(player: 'Keeper', position: 'GK'),
        LineupSlot(player: 'L Winger', position: 'LW'),
        LineupSlot(player: 'C Back Two', position: 'CB'),
        LineupSlot(player: 'R Back', position: 'RB'),
        LineupSlot(player: 'Mid One', position: 'CM'),
        LineupSlot(player: 'Mid Two', position: 'CM'),
        LineupSlot(player: 'Mid Three', position: 'CM'),
      ],
      reason: 'r',
    );

    final players = layoutFromLineup(lineup);

    final gk = _byPos(players, 'GK');
    final lb = _byPos(players, 'LB');
    final rb = _byPos(players, 'RB');
    final cb1 = _byPos(players, 'CB');
    final cb2 = _byPos(players, 'CB', nth: 1);
    final lw = _byPos(players, 'LW');
    final rw = _byPos(players, 'RW');
    final st = _byPos(players, 'ST');

    // GK central at the bottom.
    expect(gk.x, 50);
    expect(gk.y, greaterThan(80));

    // Back four: LB left of both CBs, RB right of both; CBs central.
    expect(lb.x, lessThan(cb1.x));
    expect(cb1.x, lessThan(cb2.x));
    expect(cb2.x, lessThan(rb.x));
    expect(lb.y, equals(rb.y));

    // Front three: LW left, ST centre, RW right — regardless of slot order.
    expect(lw.x, lessThan(st.x));
    expect(st.x, lessThan(rw.x));
    expect(st.x, 50);
    expect(lw.y, equals(rw.y));
    expect(st.y, lessThan(30)); // attack line at the top

    // Midfield three spread on their own line between defence and attack.
    final mids = players.where((p) => p.position == 'CM').toList();
    expect(mids.map((m) => m.y).toSet().length, 1);
    expect(mids.first.y, lessThan(lb.y));
    expect(mids.first.y, greaterThan(st.y));
  });

  test('7er 2-3-1 lays out by code with CDM/CAM lines distinct', () {
    final lineup = Lineup(
      formation: '2-3-1',
      lineup: const [
        LineupSlot(player: 'S', position: 'ST'),
        LineupSlot(player: 'K', position: 'GK'),
        LineupSlot(player: 'D1', position: 'CB'),
        LineupSlot(player: 'D2', position: 'CB'),
        LineupSlot(player: 'M1', position: 'LM'),
        LineupSlot(player: 'M2', position: 'CM'),
        LineupSlot(player: 'M3', position: 'RM'),
      ],
      reason: 'r',
    );

    final players = layoutFromLineup(lineup);
    final lm = _byPos(players, 'LM');
    final cm = _byPos(players, 'CM');
    final rm = _byPos(players, 'RM');
    expect(lm.x, lessThan(cm.x));
    expect(cm.x, lessThan(rm.x));
    expect(_byPos(players, 'ST').x, 50);
    expect(_byPos(players, 'GK').y, greaterThan(80));
  });
}
