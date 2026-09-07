import 'dart:async';
import 'package:drift/drift.dart' as drift;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/supabase/auth_provider.dart';
import '../models/pomodoro_models.dart';

/// Notifier managing Pomodoro countdown state, wall-clock precision, and SQLite logging.
class PomodoroNotifier extends Notifier<PomodoroState> {
  Timer? _ticker;

  @override
  PomodoroState build() {
    ref.onDispose(() {
      _ticker?.cancel();
    });
    return const PomodoroState();
  }

  /// Start or restart countdown with specified subject, tag, and target duration.
  void startTimer({
    String? subject,
    String? tag,
    int? customSeconds,
  }) {
    _ticker?.cancel();
    final now = DateTime.now();
    final target = customSeconds ?? state.sessionType.defaultSeconds;

    state = state.copyWith(
      status: PomodoroTimerStatus.running,
      startedAt: now,
      targetSeconds: target,
      elapsedSeconds: 0,
      accumulatedPauseSeconds: 0,
      clearPausedAt: true,
      subject: subject ?? state.subject,
      tag: tag ?? state.tag,
    );

    _startTicker();
  }

  /// Pause running countdown without losing elapsed progress.
  void pauseTimer() {
    if (state.status != PomodoroTimerStatus.running) return;
    _ticker?.cancel();
    state = state.copyWith(
      status: PomodoroTimerStatus.paused,
      pausedAt: DateTime.now(),
    );
  }

  /// Resume countdown from paused state, offsetting pause duration.
  void resumeTimer() {
    if (state.status != PomodoroTimerStatus.paused || state.pausedAt == null) return;
    final pauseDuration = DateTime.now().difference(state.pausedAt!).inSeconds;

    state = state.copyWith(
      status: PomodoroTimerStatus.running,
      accumulatedPauseSeconds: state.accumulatedPauseSeconds + pauseDuration,
      clearPausedAt: true,
    );

    _startTicker();
  }

  /// Set the active session type manually (e.g. switching between Work and Break presets).
  void setSessionType(PomodoroSessionType type, {int? customSeconds}) {
    if (state.status == PomodoroTimerStatus.running) {
      pauseTimer();
    }
    state = state.copyWith(
      sessionType: type,
      targetSeconds: customSeconds ?? type.defaultSeconds,
      elapsedSeconds: 0,
      status: PomodoroTimerStatus.idle,
      accumulatedPauseSeconds: 0,
      clearPausedAt: true,
    );
  }

  /// Set subject title and tag category.
  void setSubject(String subject, {String? tag}) {
    state = state.copyWith(
      subject: subject,
      tag: tag ?? state.tag,
    );
  }

  /// Reset the timer back to idle state with current preset duration.
  void resetTimer() {
    _ticker?.cancel();
    state = state.copyWith(
      status: PomodoroTimerStatus.idle,
      elapsedSeconds: 0,
      accumulatedPauseSeconds: 0,
      clearPausedAt: true,
    );
  }

  /// Skip the current phase and advance to the next Pomodoro stage.
  Future<void> skipToNext() async {
    _ticker?.cancel();
    if (state.elapsedSeconds >= 60) {
      // Save partial session if more than 1 minute was studied
      await _persistSession(isCompleted: false);
    }
    _advanceToNextStage();
  }

  /// Conclude session when countdown finishes.
  Future<void> finishCurrentSession({bool isCompleted = true}) async {
    _ticker?.cancel();
    state = state.copyWith(
      status: PomodoroTimerStatus.completed,
      elapsedSeconds: state.targetSeconds,
    );

    await _persistSession(isCompleted: isCompleted);
    _advanceToNextStage();
  }

  void _startTicker() {
    _ticker = Timer.periodic(const Duration(milliseconds: 200), (_) {
      if (state.status != PomodoroTimerStatus.running || state.startedAt == null) {
        return;
      }

      final now = DateTime.now();
      final totalElapsed =
          now.difference(state.startedAt!).inSeconds - state.accumulatedPauseSeconds;

      if (totalElapsed >= state.targetSeconds) {
        finishCurrentSession(isCompleted: true);
      } else {
        state = state.copyWith(elapsedSeconds: totalElapsed.clamp(0, state.targetSeconds));
      }
    });
  }

  void _advanceToNextStage() {
    if (state.sessionType == PomodoroSessionType.work) {
      if (state.cycleCount >= 4) {
        // 4 work blocks complete -> Long break!
        state = state.copyWith(
          sessionType: PomodoroSessionType.longBreak,
          targetSeconds: PomodoroSessionType.longBreak.defaultSeconds,
          elapsedSeconds: 0,
          status: PomodoroTimerStatus.idle,
          cycleCount: 1, // Reset cycle
          accumulatedPauseSeconds: 0,
          clearPausedAt: true,
        );
      } else {
        // Short break
        state = state.copyWith(
          sessionType: PomodoroSessionType.shortBreak,
          targetSeconds: PomodoroSessionType.shortBreak.defaultSeconds,
          elapsedSeconds: 0,
          status: PomodoroTimerStatus.idle,
          cycleCount: state.cycleCount + 1,
          accumulatedPauseSeconds: 0,
          clearPausedAt: true,
        );
      }
    } else {
      // Transitioning back to Work session
      state = state.copyWith(
        sessionType: PomodoroSessionType.work,
        targetSeconds: PomodoroSessionType.work.defaultSeconds,
        elapsedSeconds: 0,
        status: PomodoroTimerStatus.idle,
        accumulatedPauseSeconds: 0,
        clearPausedAt: true,
      );
    }
  }

  Future<void> _persistSession({required bool isCompleted}) async {
    final db = ref.read(appDatabaseProvider);
    final userId = ref.read(activeUserIdProvider);
    final now = DateTime.now();

    final sessionCompanion = StudySessionsCompanion.insert(
      id: const Uuid().v4(),
      userId: drift.Value(userId),
      subject: state.subject,
      tag: drift.Value(state.tag),
      sessionType: state.sessionType.id,
      durationSeconds: state.targetSeconds,
      actualSeconds: state.elapsedSeconds,
      startedAt: state.startedAt ?? now,
      completedAt: drift.Value(now),
      isCompleted: drift.Value(isCompleted),
      createdAt: drift.Value(now),
      isSynced: const drift.Value(false),
    );

    await db.insertStudySession(sessionCompanion);
  }
}

/// Provider exposing Pomodoro timing controls and state.
final pomodoroNotifierProvider =
    NotifierProvider<PomodoroNotifier, PomodoroState>(PomodoroNotifier.new);

/// Provider streaming recent study sessions from SQLite.
final recentStudySessionsStreamProvider =
    StreamProvider<List<StudySession>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchRecentStudySessions(limit: 30);
});

/// Provider streaming today's study sessions starting from local midnight.
final todayStudySessionsStreamProvider =
    StreamProvider<List<StudySession>>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final now = DateTime.now();
  final localMidnight = DateTime(now.year, now.month, now.day);
  return db.watchTodayStudySessions(localMidnight);
});

/// Provider calculating total focused work seconds completed today.
final todayStudyWorkSecondsProvider = Provider<int>((ref) {
  final sessionsAsync = ref.watch(todayStudySessionsStreamProvider);
  return sessionsAsync.maybeWhen(
    data: (sessions) => sessions
        .where((s) => s.sessionType == 'work')
        .fold(0, (sum, s) => sum + s.actualSeconds),
    orElse: () => 0,
  );
});
