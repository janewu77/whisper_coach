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

/// Convert a Lineup from the API into positioned PitchPlayers using
/// heuristic formation layouts.
List<PitchPlayer> layoutFromLineup(Lineup lineup) {
  final slots = lineup.lineup;
  final formation = lineup.formation; // e.g. "4-3-3"
  final positions = _formationPositions(formation, slots.length);

  return List.generate(slots.length, (i) {
    final slot = slots[i];
    final pos = i < positions.length ? positions[i] : _PosXY(50, 50);
    final parts = slot.player.split(' ');
    final initials = parts.length >= 2
        ? '${parts[0][0]}.${parts[1][0]}'
        : slot.player.substring(0, 2).toUpperCase();
    return PitchPlayer(
      id: '$i',
      initials: initials,
      label: slot.displayName,
      position: slot.position,
      x: pos.x,
      y: pos.y,
    );
  });
}

class _PosXY {
  final double x, y;
  const _PosXY(this.x, this.y);
}

/// Heuristic x,y% positions for common formations.
/// GK at y≈88, defenders ≈72, midfielders ≈50, forwards ≈22.
List<_PosXY> _formationPositions(String formation, int count) {
  switch (formation) {
    case '4-3-3':
      return const [
        _PosXY(50, 88), // GK
        _PosXY(15, 72), _PosXY(37, 72), _PosXY(63, 72), _PosXY(85, 72), // def
        _PosXY(22, 50), _PosXY(50, 50), _PosXY(78, 50), // mid
        _PosXY(20, 25), _PosXY(50, 20), _PosXY(80, 25), // fwd
      ];
    case '4-2-3-1':
      return const [
        _PosXY(50, 88),
        _PosXY(15, 72), _PosXY(37, 72), _PosXY(63, 72), _PosXY(85, 72),
        _PosXY(33, 57), _PosXY(67, 57),
        _PosXY(20, 40), _PosXY(50, 40), _PosXY(80, 40),
        _PosXY(50, 22),
      ];
    case '3-5-2':
      return const [
        _PosXY(50, 88),
        _PosXY(25, 72), _PosXY(50, 70), _PosXY(75, 72),
        _PosXY(10, 50), _PosXY(30, 50), _PosXY(50, 50), _PosXY(70, 50), _PosXY(90, 50),
        _PosXY(35, 24), _PosXY(65, 24),
      ];
    default:
      // Generic: parse "a-b-c…" (outfield rows, defence → attack; GK implicit)
      // so 7er/5er formations like 2-3-1 or 1-2-1 lay out correctly.
      final rows = formation
          .split('-')
          .map(int.tryParse)
          .whereType<int>()
          .toList();
      final outfield = rows.fold<int>(0, (a, b) => a + b);
      if (rows.isNotEmpty && outfield == count - 1) {
        final positions = <_PosXY>[const _PosXY(50, 88)]; // GK
        for (var r = 0; r < rows.length; r++) {
          // y from defence (≈72) up to attack (≈22).
          final y = rows.length == 1
              ? 47.0
              : 72.0 - r * (50.0 / (rows.length - 1));
          final n = rows[r];
          for (var c = 0; c < n; c++) {
            positions.add(_PosXY(100.0 * (c + 1) / (n + 1), y));
          }
        }
        return positions;
      }
      // Fallback: evenly distribute
      return List.generate(count, (i) {
        final row = i ~/ 4;
        final col = i % 4;
        return _PosXY(15.0 + col * 23.3, 85.0 - row * 20.0);
      });
  }
}

// ── PitchView ────────────────────────────────────────────────────────────────

class PitchView extends StatelessWidget {
  final List<PitchPlayer> players;
  final String? selectedId;
  final void Function(PitchPlayer player)? onTap;

  const PitchView({
    super.key,
    required this.players,
    this.selectedId,
    this.onTap,
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

    return Positioned(
      left: cx - boxW / 2,
      top: cy - boxH / 2,
      child: GestureDetector(
        onTap: () => onTap?.call(p),
        child: SizedBox(
          width: boxW,
          height: boxH,
          child: _PlayerDot(
            player: p,
            selected: isSelected,
          ),
        ),
      ),
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
