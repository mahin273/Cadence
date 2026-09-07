import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/study/models/pomodoro_models.dart';
import 'package:cadence/features/study/providers/pomodoro_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PomodoroNotifier & Study Database Operations', () {
    late AppDatabase db;
    late ProviderContainer container;
    const testUserId = 'test-study-user';

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => testUserId),
        ],
      );
    });

    tearDown(() async {
      container.dispose();
      await db.close();
    });

    test('initial state matches Pomodoro defaults (25m, Work, Cycle 1, Idle)', () {
      final state = container.read(pomodoroNotifierProvider);
      expect(state.status, PomodoroTimerStatus.idle);
      expect(state.sessionType, PomodoroSessionType.work);
      expect(state.targetSeconds, 25 * 60);
      expect(state.elapsedSeconds, 0);
      expect(state.remainingSeconds, 25 * 60);
      expect(state.progress, 0.0);
      expect(state.cycleCount, 1);
      expect(state.timeFormatted, '25:00');
    });

    test('startTimer, pauseTimer, and resumeTimer transition states with wall-clock tracking', () async {
      final notifier = container.read(pomodoroNotifierProvider.notifier);

      notifier.startTimer(subject: 'Calculus', tag: 'Math', customSeconds: 1500);
      var state = container.read(pomodoroNotifierProvider);
      expect(state.status, PomodoroTimerStatus.running);
      expect(state.subject, 'Calculus');
      expect(state.tag, 'Math');
      expect(state.startedAt, isNotNull);

      // Pause
      notifier.pauseTimer();
      state = container.read(pomodoroNotifierProvider);
      expect(state.status, PomodoroTimerStatus.paused);
      expect(state.pausedAt, isNotNull);

      // Resume
      notifier.resumeTimer();
      state = container.read(pomodoroNotifierProvider);
      expect(state.status, PomodoroTimerStatus.running);
      expect(state.pausedAt, isNull);

      notifier.resetTimer();
      state = container.read(pomodoroNotifierProvider);
      expect(state.status, PomodoroTimerStatus.idle);
      expect(state.elapsedSeconds, 0);
    });

    test('finishCurrentSession persists to SQLite and advances cycle to shortBreak', () async {
      final notifier = container.read(pomodoroNotifierProvider.notifier);

      notifier.startTimer(subject: 'Data Structures', tag: 'CS', customSeconds: 1500);
      await notifier.finishCurrentSession(isCompleted: true);

      // Verify state transitioned to short break and cycle incremented
      final state = container.read(pomodoroNotifierProvider);
      expect(state.sessionType, PomodoroSessionType.shortBreak);
      expect(state.targetSeconds, 5 * 60);
      expect(state.cycleCount, 2);
      expect(state.status, PomodoroTimerStatus.idle);

      // Verify row in SQLite
      final sessions = await db.watchRecentStudySessions().first;
      expect(sessions.length, 1);
      final session = sessions.first;
      expect(session.subject, 'Data Structures');
      expect(session.tag, 'CS');
      expect(session.sessionType, 'work');
      expect(session.isCompleted, isTrue);
      expect(session.durationSeconds, 1500);
      expect(session.userId, testUserId);
    });

    test('4-cycle progression triggers Long Break on 4th work block completion', () async {
      final notifier = container.read(pomodoroNotifierProvider.notifier);

      // Cycle 1: Work -> Short Break
      notifier.startTimer(subject: 'Block 1');
      await notifier.finishCurrentSession();
      expect(container.read(pomodoroNotifierProvider).sessionType, PomodoroSessionType.shortBreak);
      expect(container.read(pomodoroNotifierProvider).cycleCount, 2);

      // Cycle 2: Short Break -> Work
      notifier.startTimer();
      await notifier.finishCurrentSession();
      expect(container.read(pomodoroNotifierProvider).sessionType, PomodoroSessionType.work);

      // Cycle 2 Work -> Short Break
      notifier.startTimer(subject: 'Block 2');
      await notifier.finishCurrentSession();
      expect(container.read(pomodoroNotifierProvider).sessionType, PomodoroSessionType.shortBreak);
      expect(container.read(pomodoroNotifierProvider).cycleCount, 3);

      // Cycle 3: Short Break -> Work
      notifier.startTimer();
      await notifier.finishCurrentSession();
      expect(container.read(pomodoroNotifierProvider).sessionType, PomodoroSessionType.work);

      // Cycle 3 Work -> Short Break
      notifier.startTimer(subject: 'Block 3');
      await notifier.finishCurrentSession();
      expect(container.read(pomodoroNotifierProvider).sessionType, PomodoroSessionType.shortBreak);
      expect(container.read(pomodoroNotifierProvider).cycleCount, 4);

      // Cycle 4: Short Break -> Work
      notifier.startTimer();
      await notifier.finishCurrentSession();
      expect(container.read(pomodoroNotifierProvider).sessionType, PomodoroSessionType.work);

      // Cycle 4 Work -> LONG BREAK!
      notifier.startTimer(subject: 'Block 4');
      await notifier.finishCurrentSession();
      final finalState = container.read(pomodoroNotifierProvider);
      expect(finalState.sessionType, PomodoroSessionType.longBreak);
      expect(finalState.targetSeconds, 15 * 60);
      expect(finalState.cycleCount, 1); // Reset cycle
    });

    test('getTodayTotalStudySeconds sums only work sessions for today', () async {
      final now = DateTime.now();
      final todayMidnight = DateTime(now.year, now.month, now.day);
      final notifier = container.read(pomodoroNotifierProvider.notifier);

      // Work session (25 mins = 1500s)
      notifier.startTimer(subject: 'Coding', customSeconds: 1500);
      await notifier.finishCurrentSession();

      // Break session (5 mins = 300s)
      notifier.startTimer(subject: 'Break', customSeconds: 300);
      await notifier.finishCurrentSession();

      // Total work seconds should only be 1500
      final totalWork = await db.getTodayTotalStudySeconds(todayMidnight);
      expect(totalWork, 1500);
    });

    test('deleteStudySession removes session from database', () async {
      final notifier = container.read(pomodoroNotifierProvider.notifier);
      notifier.startTimer(subject: 'Temporary Study', customSeconds: 600);
      await notifier.finishCurrentSession();

      var sessions = await db.watchRecentStudySessions().first;
      expect(sessions.length, 1);

      await db.deleteStudySession(sessions.first.id);
      sessions = await db.watchRecentStudySessions().first;
      expect(sessions, isEmpty);
    });
  });
}
