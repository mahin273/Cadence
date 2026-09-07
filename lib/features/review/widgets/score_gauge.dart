import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Expressive radial gauge displaying the 0-100 Life Rhythm Score.
class ScoreGauge extends StatelessWidget {
  final int score;
  final double size;

  const ScoreGauge({
    super.key,
    required this.score,
    this.size = 180,
  });

  Color _getScoreColor(int score) {
    if (score >= 85) return const Color(0xFF10B981); // Emerald
    if (score >= 70) return const Color(0xFF06B6D4); // Cyan
    if (score >= 50) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFF43F5E); // Rose
  }

  String _getScoreLabel(int score) {
    if (score >= 85) return 'Flourishing';
    if (score >= 70) return 'Balanced';
    if (score >= 50) return 'Building Rhythm';
    return 'Needs Tuning';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final targetColor = _getScoreColor(score);
    final targetFraction = (score / 100.0).clamp(0.0, 1.0);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: size,
          height: size,
          child: TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0.0, end: targetFraction),
            duration: const Duration(milliseconds: 1200),
            curve: Curves.easeOutCubic,
            builder: (context, value, child) {
              return CustomPaint(
                painter: _ScoreGaugePainter(
                  fraction: value,
                  color: targetColor,
                  trackColor: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
                ),
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${(value * 100).round()}',
                        style: theme.textTheme.displayMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                          color: targetColor,
                        ),
                      ),
                      Text(
                        'LIFE RHYTHM',
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: targetColor.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: targetColor.withValues(alpha: 0.4)),
          ),
          child: Text(
            _getScoreLabel(score),
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: targetColor,
            ),
          ),
        ),
      ],
    );
  }
}

class _ScoreGaugePainter extends CustomPainter {
  final double fraction;
  final Color color;
  final Color trackColor;

  _ScoreGaugePainter({
    required this.fraction,
    required this.color,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - 24) / 2;
    const strokeWidth = 14.0;
    const startAngle = math.pi * 0.75;
    const sweepAngleTotal = math.pi * 1.5;

    // Background track arc
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngleTotal,
      false,
      trackPaint,
    );

    // Active progress arc
    if (fraction > 0) {
      final activePaint = Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngleTotal * fraction,
        false,
        activePaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ScoreGaugePainter oldDelegate) =>
      oldDelegate.fraction != fraction ||
      oldDelegate.color != color ||
      oldDelegate.trackColor != trackColor;
}
