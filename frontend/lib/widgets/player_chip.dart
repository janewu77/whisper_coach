import 'package:flutter/material.dart';
import '../theme.dart';

/// Small pill chip showing a player's name.
/// Used in the "Detected players" section on HomeScreen.
class PlayerChip extends StatelessWidget {
  final String name;
  final bool flagged; // amber = uncertain extraction

  const PlayerChip({super.key, required this.name, this.flagged = false});

  @override
  Widget build(BuildContext context) {
    final bg = flagged ? kAmberBg : kGreenBg;
    final fg = flagged ? kAmberFg : kGreenFg;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(
          color: flagged ? kAmberFg.withOpacity(0.3) : kBrandBorder,
          width: 0.5,
        ),
      ),
      child: Text(
        name,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          color: fg,
          height: 1.4,
        ),
      ),
    );
  }
}
