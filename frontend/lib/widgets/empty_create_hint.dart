import 'package:flutter/material.dart';

import '../theme.dart';

/// Empty-state hint shown when a list has no items. Instead of a center button,
/// it nudges the user toward the voice/photo FABs with a gentle AI pulse.
class EmptyCreateHint extends StatefulWidget {
  final String title;
  final String message;

  const EmptyCreateHint({super.key, required this.title, required this.message});

  @override
  State<EmptyCreateHint> createState() => _EmptyCreateHintState();
}

class _EmptyCreateHintState extends State<EmptyCreateHint>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2000),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 132,
              height: 132,
              child: AnimatedBuilder(
                animation: _c,
                builder: (context, _) {
                  return Stack(
                    alignment: Alignment.center,
                    children: [
                      _ring((_c.value) % 1.0),
                      _ring((_c.value + 0.5) % 1.0),
                      Container(
                        width: 68,
                        height: 68,
                        decoration: const BoxDecoration(
                          color: kBrandSubtle,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.auto_awesome,
                            color: kTextBrand, size: 32),
                      ),
                    ],
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            Text(widget.title,
                textAlign: TextAlign.center, style: kStyleScreenTitle),
            const SizedBox(height: 6),
            Text(widget.message,
                textAlign: TextAlign.center, style: kStyleSecondary),
            const SizedBox(height: 18),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: const [
                _HintChip(icon: Icons.mic_none_rounded, label: 'Speak'),
                _HintChip(
                    icon: Icons.add_a_photo_outlined, label: 'Upload a photo'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _ring(double t) {
    final size = 68 + t * 60;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: kBrand.withValues(alpha: (1 - t) * 0.22),
      ),
    );
  }
}

class _HintChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _HintChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: kBrandSubtle,
        borderRadius: BorderRadius.circular(100),
        border: Border.all(color: kBrandBorder.withValues(alpha: 0.5), width: 0.5),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: kTextBrand),
          const SizedBox(width: 6),
          Text(label,
              style: kStyleSecondary.copyWith(
                  color: kTextBrand, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
