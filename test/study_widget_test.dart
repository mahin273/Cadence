import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/study/models/pomodoro_models.dart';
import 'package:cadence/features/study/presentation/pomodoro_view.dart';
import 'package:cadence/features/study/providers/pomodoro_provider.dart';
import 'package:cadence/features/study/widgets/focus_timer_card.dart';
import 'package:cadence/features/study/widgets/pomodoro_progress_dial.dart';
import 'package:cadence/features/study/widgets/study_history_list.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestApp({
    required AppDatabase db,
    required Widget child,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeUserIdProvider.overrideWith((ref) => 'test-study-user'),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: child),
      ),
    );
  }

  group('Study & Pomodoro UI Widgets', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('PomodoroProgressDial renders session badge, countdown time, and subject', (tester) async {
      const state = PomodoroState(
        status: PomodoroTimerStatus.running,
        sessionType: PomodoroSessionType.work,
        targetSeconds: 1500,
        elapsedSeconds: 300,
        subject: 'Algorithms & Data Structures',
        cycleCount: 2,
      );

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PomodoroProgressDial(state: state),
          ),
        ),
      );
      await tester.pump();

      expect(find.text('FOCUS WORK'), findsOneWidget);
      expect(find.text('20:00'), findsOneWidget); // 1500 - 300 = 1200s = 20:00
      expect(find.text('Algorithms & Data Structures'), findsOneWidget);
    });

    testWidgets('FocusTimerCard renders on dashboard and starts focus timer on tap', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: const FocusTimerCard(),
        ),
      );
      await tester.pump();

      expect(find.text('Deep Focus & Study'), findsOneWidget);
      expect(find.text('Start 25m Focus'), findsOneWidget);

      // Tap start button
      await tester.tap(find.text('Start 25m Focus'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Now card should show live timer controls
      expect(find.byIcon(Icons.pause_rounded), findsOneWidget);
      expect(find.byIcon(Icons.stop_rounded), findsOneWidget);

      // Tap pause so timer cancels cleanly before test completion
      await tester.tap(find.byIcon(Icons.pause_rounded));
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('PomodoroView renders presets, dial, and control buttons', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: const PomodoroView(),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Focus & Study'), findsOneWidget);
      expect(find.text('25m Pomodoro'), findsOneWidget);
      expect(find.text('50m Ultradian'), findsOneWidget);
      expect(find.text('90m Deep Block'), findsOneWidget);
      expect(find.text('Start Focus Work'), findsOneWidget);

      // Tap 50m Ultradian chip
      await tester.tap(find.text('50m Ultradian'));
      await tester.pump();

      expect(find.text('50:00'), findsOneWidget);

      // Tap Start
      await tester.tap(find.text('Start Focus Work'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Pause'), findsOneWidget);
      expect(find.byIcon(Icons.skip_next_rounded), findsOneWidget);

      // Tap pause so timer cancels cleanly before test completion
      await tester.tap(find.text('Pause'));
      await tester.pump();

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('StudyHistoryList renders empty card initially and updates when session is logged', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: const StudyHistoryList(),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('No study sessions logged yet'), findsOneWidget);

      // Insert a study session directly into db
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          activeUserIdProvider.overrideWith((ref) => 'test-study-user'),
        ],
      );
      final notifier = container.read(pomodoroNotifierProvider.notifier);
      notifier.startTimer(subject: 'Operating Systems', customSeconds: 1500);
      await notifier.finishCurrentSession();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: Scaffold(body: StudyHistoryList()),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Operating Systems'), findsOneWidget);
      expect(find.textContaining('25 mins'), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
      container.dispose();
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}
