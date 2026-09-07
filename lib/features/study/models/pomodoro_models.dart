import 'package:flutter/material.dart';

/// Phase / type of Pomodoro session.
enum PomodoroSessionType {
  work('work', 'Focus Work', 25 * 60, Icons.psychology_rounded, Color(0xFFFF9800)),
  shortBreak('short_break', 'Short Break', 5 * 60, Icons.coffee_rounded, Color(0xFF4CAF50)),
  longBreak('long_break', 'Long Break', 15 * 60, Icons.park_rounded, Color(0xFF2196F3));

  final String id;
  final String label;
  final int defaultSeconds;
  final IconData icon;
  final Color color;

  const PomodoroSessionType(
    this.id,
    this.label,
    this.defaultSeconds,
    this.icon,
    this.color,
  );

  static PomodoroSessionType fromId(String id) {
    switch (id) {
      case 'short_break':
        return PomodoroSessionType.shortBreak;
      case 'long_break':
        return PomodoroSessionType.longBreak;
      case 'work':
      default:
        return PomodoroSessionType.work;
    }
  }
}

/// Operational state of the focus countdown timer.
enum PomodoroTimerStatus {
  idle,
  running,
  paused,
  completed,
}

/// Immutable state snapshot of the active Pomodoro session.
class PomodoroState {
  final PomodoroTimerStatus status;
  final PomodoroSessionType sessionType;
  final int targetSeconds;
  final int elapsedSeconds;
  final String subject;
  final String? tag;
  final int cycleCount; // 1 through 4
  final DateTime? startedAt;
  final DateTime? pausedAt;
  final int accumulatedPauseSeconds;

  const PomodoroState({
    this.status = PomodoroTimerStatus.idle,
    this.sessionType = PomodoroSessionType.work,
    this.targetSeconds = 25 * 60,
    this.elapsedSeconds = 0,
    this.subject = 'Deep Work',
    this.tag = 'Study',
    this.cycleCount = 1,
    this.startedAt,
    this.pausedAt,
    this.accumulatedPauseSeconds = 0,
  });

  PomodoroState copyWith({
    PomodoroTimerStatus? status,
    PomodoroSessionType? sessionType,
    int? targetSeconds,
    int? elapsedSeconds,
    String? subject,
    String? tag,
    int? cycleCount,
    DateTime? startedAt,
    DateTime? pausedAt,
    int? accumulatedPauseSeconds,
    bool clearPausedAt = false,
  }) {
    return PomodoroState(
      status: status ?? this.status,
      sessionType: sessionType ?? this.sessionType,
      targetSeconds: targetSeconds ?? this.targetSeconds,
      elapsedSeconds: elapsedSeconds ?? this.elapsedSeconds,
      subject: subject ?? this.subject,
      tag: tag ?? this.tag,
      cycleCount: cycleCount ?? this.cycleCount,
      startedAt: startedAt ?? this.startedAt,
      pausedAt: clearPausedAt ? null : (pausedAt ?? this.pausedAt),
      accumulatedPauseSeconds:
          accumulatedPauseSeconds ?? this.accumulatedPauseSeconds,
    );
  }

  /// Remaining seconds in the session countdown.
  int get remainingSeconds =>
      (targetSeconds - elapsedSeconds).clamp(0, targetSeconds);

  /// Fractional progress from 0.0 (start) to 1.0 (completed).
  double get progress =>
      targetSeconds == 0 ? 0.0 : (elapsedSeconds / targetSeconds).clamp(0.0, 1.0);

  /// Display string formatted as MM:SS.
  String get timeFormatted {
    final minutes = (remainingSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (remainingSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  /// True if current phase is either short or long break.
  bool get isBreak =>
      sessionType == PomodoroSessionType.shortBreak ||
      sessionType == PomodoroSessionType.longBreak;
}
