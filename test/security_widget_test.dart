import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/native.dart';
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/database/database_provider.dart';
import 'package:cadence/core/security/biometric_service.dart';
import 'package:cadence/core/security/security_providers.dart';
import 'package:cadence/core/security/presentation/app_lock_screen.dart';
import 'package:cadence/core/security/presentation/security_settings_view.dart';
import 'package:cadence/app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget createWidgetUnderTest({
    required Widget child,
    List<dynamic> overrides = const [],
  }) {
    return ProviderScope(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        biometricServiceProvider.overrideWithValue(
          BiometricService(forceMock: true, mockAuthSuccess: true),
        ),
        ...overrides,
      ],
      child: MaterialApp(
        home: child,
      ),
    );
  }

  group('AppLockScreen Widget Tests', () {
    testWidgets('Renders locked state and unlocks upon successful biometric auth',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          biometricServiceProvider.overrideWithValue(
            BiometricService(forceMock: true, mockAuthSuccess: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(isAppLockedProvider.notifier).lock();
      expect(container.read(isAppLockedProvider), isTrue);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppLockScreen(),
          ),
        ),
      );

      expect(find.text('Cadence is Locked'), findsOneWidget);
      expect(find.text('Unlock with Biometrics'), findsOneWidget);
      expect(find.byIcon(Icons.lock_rounded), findsOneWidget);

      await tester.tap(find.text('Unlock with Biometrics'));
      await tester.pumpAndSettle();

      expect(container.read(isAppLockedProvider), isFalse);
    });

    testWidgets('Displays error message when biometric authentication fails',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          biometricServiceProvider.overrideWithValue(
            BiometricService(forceMock: true, mockAuthSuccess: false),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: AppLockScreen(),
          ),
        ),
      );

      await tester.tap(find.text('Unlock with Biometrics'));
      await tester.pumpAndSettle();

      expect(
        find.text('Authentication canceled or not recognized.'),
        findsOneWidget,
      );
    });
  });

  group('SecuritySettingsView Widget Tests', () {
    testWidgets('Renders all security sections, switches, and database footprint',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createWidgetUnderTest(
          child: const SecuritySettingsView(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Security & Data Sovereignty'), findsOneWidget);
      expect(find.text('App Security'), findsOneWidget);
      expect(find.text('Biometric App Lock'), findsOneWidget);
      expect(find.text('Database Footprint'), findsOneWidget);
      expect(find.text('Data Sovereignty & Portability'), findsOneWidget);
      expect(find.text('Export Full Database (JSON)'), findsOneWidget);
      expect(find.text('Restore Database from JSON'), findsOneWidget);
    });

    testWidgets('Toggling biometric lock triggers verification and updates preference',
        (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          biometricServiceProvider.overrideWithValue(
            BiometricService(forceMock: true, mockAuthSuccess: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            home: SecuritySettingsView(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(container.read(appLockEnabledProvider), isFalse);

      // Tap SwitchListTile
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();

      expect(container.read(appLockEnabledProvider), isTrue);
      expect(find.text('Lock Application Now'), findsOneWidget);
    });

    testWidgets('Export button opens JSON export preview dialog',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createWidgetUnderTest(
          child: const SecuritySettingsView(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Export Full Database (JSON)'));
      await tester.pumpAndSettle();

      expect(find.text('Export Generated'), findsOneWidget);
      expect(find.text('Copy JSON'), findsOneWidget);
      expect(find.text('Share Backup'), findsOneWidget);

      await tester.tap(find.text('Copy JSON'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Export JSON copied to clipboard!'), findsOneWidget);
    });

    testWidgets('Restore button opens JSON restore dialog with warning',
        (tester) async {
      tester.view.physicalSize = const Size(800, 1600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        createWidgetUnderTest(
          child: const SecuritySettingsView(),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Restore Database from JSON'));
      await tester.pumpAndSettle();

      expect(find.text('Restore Database'), findsOneWidget);
      expect(
        find.textContaining('Restoring will overwrite existing local records'),
        findsOneWidget,
      );
      expect(find.text('Restore Data'), findsOneWidget);

      // Cancel dialog
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(find.text('Restore Database'), findsNothing);
    });
  });

  group('CadenceApp AppLock Integration Test', () {
    testWidgets('CadenceApp renders AppLockScreen when locked', (tester) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          biometricServiceProvider.overrideWithValue(
            BiometricService(forceMock: true, mockAuthSuccess: true),
          ),
        ],
      );
      addTearDown(container.dispose);

      container.read(isAppLockedProvider.notifier).lock();

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const CadenceApp(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Cadence is Locked'), findsOneWidget);
      expect(find.text('Unlock with Biometrics'), findsOneWidget);

      // Unlock
      await tester.tap(find.text('Unlock with Biometrics'));
      await tester.pumpAndSettle();

      // Now Dashboard is visible
      expect(find.text('Cadence'), findsOneWidget);
    });
  });
}
