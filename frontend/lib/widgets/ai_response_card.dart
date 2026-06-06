import 'package:flutter/material.dart';
import '../models/suggestion.dart';
import '../theme.dart';

/// Tinted card rendering an AI tactical Suggestion.
/// Shows substitutions, position changes, and reasoning.
class AiResponseCard extends StatelessWidget {
  final Suggestion suggestion;

  const AiResponseCard({super.key, required this.suggestion});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: kBrandSubtle,
        borderRadius: BorderRadius.circular(kRadiusCard),
        border: Border.all(color: kBrandBorder.withOpacity(0.5), width: 0.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              const Icon(Icons.tips_and_updates_outlined,
                  size: 14, color: kTextBrand),
              const SizedBox(width: 5),
              Text(
                'Whisper Coach',
                style: const TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: kTextBrand,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Substitutions
          if (suggestion.substitutions.isNotEmpty) ...[
            for (final s in suggestion.substitutions)
              _line(
                label: 'Substitution:',
                text: 'Replace ${s.out} → ${s.inPlayer}',
              ),
            const SizedBox(height: 4),
          ],

          // Position changes
          if (suggestion.positionChanges.isNotEmpty) ...[
            for (final p in suggestion.positionChanges)
              _line(
                label: 'Move:',
                text: '${p.player} → ${p.to}',
              ),
            const SizedBox(height: 4),
          ],

          // Reasoning
          if (suggestion.reason.isNotEmpty)
            Text(
              suggestion.reason,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w400,
                color: kTextPrimary,
                height: 1.55,
              ),
            ),
        ],
      ),
    );
  }

  Widget _line({required String label, required String text}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: RichText(
        text: TextSpan(
          style: const TextStyle(
            fontSize: 13,
            color: kTextPrimary,
            height: 1.5,
          ),
          children: [
            TextSpan(
              text: '$label ',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
            TextSpan(text: text),
          ],
        ),
      ),
    );
  }
}
