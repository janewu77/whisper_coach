import 'package:flutter/material.dart';
import '../models/lineup.dart';
import '../theme.dart';

/// A positioned player on the pitch.
/// [x] and [y] are percentages (0–100) of pitch width/height.
/// GK is near y=88, forwards near y=22.
class PitchPlayer {
  final String id;
  final String initials; // e.g. "O.S"
  final String label; // shown under the dot: nickname, or the full name
  final String position; // e.g. "ST"
  final double x; // 0–100 %
  final double y; // 0–100 %

  const PitchPlayer({
    required this.id,
    required this.initials,
    required this.label,
    required this.position,
    required this.x,
    required this.y,
  });
}

/// Convert a Lineup from the API into positioned PitchPlayers.
///
/// Layout is driven by each slot's POSITION CODE, not by the order the agent
/// returned the players in: the code decides the line (GK → defence → CDM →
/// midfield → CAM → attack) and the side (L… left, R… right, centre codes
/// centre), and each line spreads its players evenly. So a CB is always
/// central, an LW always left and an RW always right — for any formation.
List<PitchPlayer> layoutFromLineup(Lineup lineup) {
  final slots = lineup.lineup;

  final coords = _layoutByPosition(slots);

  return List.generate(slots.length, (i) {
    final slot = slots[i];
    final parts =
        slot.player.trim().split(' ').where((p) => p.isNotEmpty).toList();
    final initials = parts.length >= 2
        ? '${parts[0][0]}.${parts[1][0]}'
        : (parts.isEmpty
            ? '?'
            : parts[0]
                .substring(0, parts[0].length < 2 ? 1 : 2)
                .toUpperCase());
    return PitchPlayer(
      id: '$i',
      initials: initials,
      label: slot.displayName,
      position: slot.position,
      x: coords[i].x,
      y: coords[i].y,
    );
  });
}

class _PosXY {
  final double x, y;
  const _PosXY(this.x, this.y);
}

/// Vertical line on the pitch for a position code (0 = GK … 5 = attack).
int _lineOf(String pos) {
  switch (pos.trim().toUpperCase()) {
    case 'GK':
      return 0;
    case 'LB':
    case 'CB':
    case 'RB':
    case 'LWB':
    case 'RWB':
    case 'SW':
      return 1;
    case 'CDM':
    case 'DM':
      return 2;
    case 'LM':
    case 'CM':
    case 'RM':
      return 3;
    case 'CAM':
    case 'AM':
      return 4;
    case 'LW':
    case 'RW':
    case 'ST':
    case 'CF':
    case 'FW':
      return 5;
    default:
      return 3; // unknown → midfield
  }
}

/// Horizontal ordering within a line: left codes → centre codes → right codes.
int _sideOf(String pos) {
  final p = pos.trim().toUpperCase();
  if (p == 'GK') return 1;
  if (p.startsWith('L')) return 0;
  if (p.startsWith('R')) return 2;
  return 1;
}

/// y% for each line.
const Map<int, double> _lineY = {
  0: 88, // GK
  1: 72, // defence
  2: 57, // CDM
  3: 47, // midfield
  4: 37, // CAM
  5: 23, // attack
};

List<_PosXY> _layoutByPosition(List<LineupSlot> slots) {
  // Group slot indexes by line.
  final byLine = <int, List<int>>{};
  for (var i = 0; i < slots.length; i++) {
    byLine.putIfAbsent(_lineOf(slots[i].position), () => []).add(i);
  }

  final coords = List<_PosXY>.filled(slots.length, const _PosXY(50, 50));
  byLine.forEach((line, idxs) {
    // Left → centre → right; original order as a stable tie-breaker (so two
    // CBs keep their relative order and spread around the centre).
    idxs.sort((a, b) {
      final s = _sideOf(slots[a].position) - _sideOf(slots[b].position);
      return s != 0 ? s : a - b;
    });
    for (var k = 0; k < idxs.length; k++) {
      coords[idxs[k]] =
          _PosXY(100.0 * (k + 1) / (idxs.length + 1), _lineY[line]!);
    }
  });
  return coords;
}

// ── Drag payloads (pitch ↔ bench) ────────────────────────────────────────────

/// A starter being dragged (index into Lineup.lineup).
class StarterDrag {
  final int index;
  const StarterDrag(this.index);
}

/// A sub being dragged (index into Lineup.subs).
class SubDrag {
  final int index;
  const SubDrag(this.index);
}

// ── PitchView ────────────────────────────────────────────────────────────────

class PitchView extends StatelessWidget {
  final List<PitchPlayer> players;
  final String? selectedId;
  final void Function(PitchPlayer player)? onTap;

  /// Drag & drop (long-press a dot): swap two starters' positions…
  final void Function(int a, int b)? onSwapStarters;

  /// …or drop a bench player onto a starter (sub in / starter out).
  final void Function(int subIndex, int starterIndex)? onSubIn;

  const PitchView({
    super.key,
    required this.players,
    this.selectedId,
    this.onTap,
    this.onSwapStarters,
    this.onSubIn,
  });

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 0.65, // taller than wide — portrait pitch
      child: LayoutBuilder(builder: (context, constraints) {
        final w = constraints.maxWidth;
        final h = constraints.maxHeight;
        return Stack(
          children: [
            // Pitch background
            ClipRRect(
              borderRadius: BorderRadius.circular(kRadiusSheet),
              child: CustomPaint(
                size: Size(w, h),
                painter: _PitchPainter(),
              ),
            ),
            // Player dots
            for (final p in players) _buildDot(p, w, h),
            // AI badge
            Positioned(
              right: 10,
              bottom: 10,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: kSurfaceInverse.withOpacity(0.85),
                  borderRadius: BorderRadius.circular(100),
                ),
                child: const Text(
                  'AI generated',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
          ],
        );
      }),
    );
  }

  Widget _buildDot(PitchPlayer p, double w, double h) {
    const boxW = 64.0;
    const boxH = 50.0;
    final cx = (p.x / 100) * w;
    final cy = (p.y / 100) * h;
    final isSelected = selectedId == p.id;
    final index = int.tryParse(p.id) ?? 0;

    final dot = SizedBox(
      width: boxW,
      height: boxH,
      child: _PlayerDot(player: p, selected: isSelected),
    );
    final tappable = GestureDetector(
      onTap: () => onTap?.call(p),
      child: dot,
    );
    Widget child = tappable;

    if (onSwapStarters != null) {
      child = DragTarget<Object>(
        onWillAcceptWithDetails: (d) =>
            (d.data is StarterDrag && (d.data as StarterDrag).index != index) ||
            d.data is SubDrag,
        onAcceptWithDetails: (d) {
          final data = d.data;
          if (data is StarterDrag) {
            onSwapStarters!(data.index, index);
          } else if (data is SubDrag) {
            onSubIn?.call(data.index, index);
          }
        },
        builder: (context, candidates, _) => LongPressDraggable<Object>(
          data: StarterDrag(index),
          delay: const Duration(milliseconds: 200),
          feedback: Material(color: Colors.transparent, child: dot),
          childWhenDragging: Opacity(opacity: 0.3, child: tappable),
          child: candidates.isEmpty
              ? tappable
              : Transform.scale(scale: 1.2, child: tappable),
        ),
      );
    }

    return Positioned(
      left: cx - boxW / 2,
      top: cy - boxH / 2,
      child: child,
    );
  }
}

class _PlayerDot extends StatelessWidget {
  final PitchPlayer player;
  final bool selected;

  const _PlayerDot({required this.player, required this.selected});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Circle with the position code (short word: ST, CM, GK…).
        Container(
          width: 30,
          height: 30,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: selected ? kBrand : kSurfaceCard,
            border: Border.all(
              color: selected ? kBrandPressed : kBrand,
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              player.position,
              style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w700,
                color: selected ? kTextOnBrand : kTextPrimary,
                height: 1.0,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        // Full nickname (or name) under the dot.
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
          decoration: BoxDecoration(
            color: selected
                ? kBrand
                : kSurfaceInverse.withOpacity(0.72),
            borderRadius: BorderRadius.circular(100),
          ),
          child: Text(
            player.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 8.5,
              fontWeight: FontWeight.w600,
              color: Colors.white,
              height: 1.2,
            ),
          ),
        ),
      ],
    );
  }
}

// ── Pitch Painter ─────────────────────────────────────────────────────────────

class _PitchPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final turfPaint = Paint()..color = kPitch;
    final stripePaint = Paint()..color = kPitchDark;
    final linePaint = Paint()
      ..color = kPitchLine
      ..strokeWidth = 1.2
      ..style = PaintingStyle.stroke;

    // Background turf
    final rrect = RRect.fromRectAndRadius(
      Rect.fromLTWH(0, 0, w, h),
      const Radius.circular(kRadiusSheet),
    );
    canvas.drawRRect(rrect, turfPaint);

    // Mowing stripes (subtle horizontal bands)
    canvas.save();
    canvas.clipRRect(rrect);
    final stripeH = h / 10;
    for (int i = 0; i < 10; i += 2) {
      canvas.drawRect(
        Rect.fromLTWH(0, i * stripeH, w, stripeH),
        stripePaint,
      );
    }
    canvas.restore();

    // Clip all line markings to the rounded rect
    canvas.save();
    canvas.clipRRect(rrect);

    final pad = w * 0.06;

    // Outer boundary
    canvas.drawRect(
      Rect.fromLTRB(pad, pad, w - pad, h - pad),
      linePaint,
    );

    // Centre line
    canvas.drawLine(Offset(pad, h / 2), Offset(w - pad, h / 2), linePaint);

    // Centre circle
    canvas.drawCircle(Offset(w / 2, h / 2), w * 0.16, linePaint);
    canvas.drawCircle(Offset(w / 2, h / 2), 2.5, linePaint..style = PaintingStyle.fill);
    linePaint.style = PaintingStyle.stroke;

    // Penalty boxes
    final boxW = w * 0.55;
    final boxH = h * 0.16;
    final boxX = (w - boxW) / 2;
    // Top box
    canvas.drawRect(Rect.fromLTWH(boxX, pad, boxW, boxH), linePaint);
    // Bottom box
    canvas.drawRect(Rect.fromLTWH(boxX, h - pad - boxH, boxW, boxH), linePaint);

    // Goal boxes
    final goalW = w * 0.28;
    final goalH = h * 0.07;
    final goalX = (w - goalW) / 2;
    canvas.drawRect(Rect.fromLTWH(goalX, pad, goalW, goalH), linePaint);
    canvas.drawRect(Rect.fromLTWH(goalX, h - pad - goalH, goalW, goalH), linePaint);

    // Penalty spots
    final spotPaint = Paint()
      ..color = kPitchLine
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(w / 2, pad + boxH * 0.6), 2.5, spotPaint);
    canvas.drawCircle(Offset(w / 2, h - pad - boxH * 0.6), 2.5, spotPaint);

    canvas.restore();
  }

  @override
  bool shouldRepaint(_PitchPainter old) => false;
}
