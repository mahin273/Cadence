import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/connection/native_connection.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/supabase/auth_provider.dart';
import 'package:cadence/features/movement/presentation/movement_view.dart';
import 'package:cadence/features/movement/providers/foreground_service_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget createTestApp({
    required AppDatabase db,
    required Widget child,
    bool isTracking = false,
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        activeUserIdProvider.overrideWith((ref) => 'test-fg-user'),
        foregroundServiceProvider.overrideWith(() => MockForegroundServiceNotifier(isTracking)),
      ],
      child: MaterialApp(
        theme: ThemeData(useMaterial3: true),
        home: Scaffold(body: child),
      ),
    );
  }

  group('Foreground Service UI Integration', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(openInMemoryConnection());
    });

    tearDown(() async {
      await db.close();
    });

    testWidgets('MovementView displays Persistent Background Service card with inactive status', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: const MovementView(),
          isTracking: false,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Persistent Background Service'), findsOneWidget);
      expect(find.text('Disabled • OS may throttle sensors when locked'), findsOneWidget);
      expect(find.byType(SwitchListTile), findsOneWidget);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });

    testWidgets('MovementView displays Active indicator when foreground service is tracking', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          db: db,
          child: const MovementView(),
          isTracking: true,
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Persistent Background Service'), findsOneWidget);
      expect(find.text('Active • Sticky notification prevents OS kill'), findsOneWidget);

      // Verify switch is ON
      final switchFinder = find.byType(Switch);
      final switchWidget = tester.widget<Switch>(switchFinder);
      expect(switchWidget.value, isTrue);

      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(milliseconds: 100));
    });
  });
}

class MockForegroundServiceNotifier extends ForegroundServiceNotifier {
  final bool initial;
  MockForegroundServiceNotifier(this.initial);

  @override
  bool build() => initial;

  @override
  Future<bool> startTracking({String title = '', String text = ''}) async {
    state = true;
    return true;
  }

  @override
  Future<bool> stopTracking() async {
    state = false;
    return true;
  }
}
