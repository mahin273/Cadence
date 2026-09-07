import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/pomodoro_models.dart';

/// Interactive circular progress countdown ring for the active Pomodoro session.
class PomodoroProgressDial extends StatelessWidget {
  final PomodoroState state;
  final VoidCallback? onCenterTap;

  const PomodoroProgressDial({
    super.key,
    required this.state,
    this.onCenterTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final phaseColor = state.sessionType.color;

    return Center(
      child: SizedBox(
        width: 260,
        height: 260,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Custom Painter Ring
            CustomPaint(
              size: const Size(260, 260),
              painter: _ProgressRingPainter(
                progress: state.progress,
                trackColor: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
                progressColor: phaseColor,
                strokeWidth: 14.0,
              ),
            ),

            // Inside Center Content
            InkWell(
              onTap: onCenterTap,
              borderRadius: BorderRadius.circular(120),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Session Type Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: phaseColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(state.sessionType.icon, size: 14, color: phaseColor),
                          const SizedBox(width: 4),
                          Text(
                            state.sessionType.label.toUpperCase(),
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                              color: phaseColor,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 8),

                    // Countdown Display
                    Text(
                      state.timeFormatted,
                      style: theme.textTheme.displayMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        letterSpacing: -1.0,
                      ),
                    ),

                    const SizedBox(height: 6),

                    // Subject Name
                    Text(
                      state.subject,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),

                    const SizedBox(height: 10),

                    // 4-Stage Cycle Dots (only for Work sessions)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: List.generate(4, (index) {
                        final isCompleted = (index + 1) < state.cycleCount;
                        final isCurrent = (index + 1) == state.cycleCount;
                        return Container(
                          margin: const EdgeInsets.symmetric(horizontal: 3),
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isCompleted
                                ? phaseColor
                                : isCurrent
                                    ? phaseColor.withValues(alpha: 0.6)
                                    : colorScheme.outlineVariant.withValues(alpha: 0.4),
                          ),
                        );
                      }),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRingPainter extends CustomPainter {
  final double progress;
  final Color trackColor;
  final Color progressColor;
  final double strokeWidth;

  _ProgressRingPainter({
    required this.progress,
    required this.trackColor,
    required this.progressColor,
    required this.strokeWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    // Track Paint
    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    canvas.drawCircle(center, radius, trackPaint);

    if (progress > 0.0) {
      // Progress Arc Paint
      final progressPaint = Paint()
        ..color = progressColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      const startAngle = -math.pi / 2;
      final sweepAngle = 2 * math.pi * progress;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        false,
        progressPaint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ProgressRingPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.trackColor != trackColor;
  }
}
