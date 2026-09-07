import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:drift/native.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:cadence/core/database/app_database.dart';
import 'package:cadence/core/security/biometric_service.dart';
import 'package:cadence/core/security/data_export_service.dart';
import 'package:cadence/core/security/security_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late AppDatabase db;
  late DataExportService exportService;

  setUp(() {
    db = AppDatabase(NativeDatabase.memory());
    exportService = DataExportService(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('BiometricService Tests', () {
    test('Mock biometric service canAuthenticate and getAvailableBiometrics',
        () async {
      final service = BiometricService(forceMock: true);
      final canAuth = await service.canAuthenticate();
      expect(canAuth, isTrue);

      final biometrics = await service.getAvailableBiometrics();
      expect(biometrics, isNotEmpty);
    });

    test('Mock biometric service authenticate returns expected success or failure',
        () async {
      final successService =
          BiometricService(forceMock: true, mockAuthSuccess: true);
      expect(await successService.authenticate(), isTrue);

      final failureService =
          BiometricService(forceMock: true, mockAuthSuccess: false);
      expect(await failureService.authenticate(), isFalse);
    });
  });

  group('DataExportService Tests', () {
    test('Exports empty database into valid JSON schema with version header',
        () async {
      final jsonString = await exportService.exportAllDataAsJson();
      expect(jsonString, isNotEmpty);

      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      expect(decoded['version'], 1);
      expect(decoded['app'], 'Cadence');
      expect(decoded['exportedAt'], isNotNull);

      final tables = decoded['tables'] as Map<String, dynamic>;
      expect(tables.containsKey('entries'), isTrue);
      expect(tables.containsKey('expenses'), isTrue);
      expect(tables.containsKey('accounts'), isTrue);
      expect(tables.containsKey('debts'), isTrue);
      expect(tables.containsKey('screenTimeSnapshots'), isTrue);
      expect((tables['entries'] as List), isEmpty);
    });

    test('Exports and imports populated database with round-trip fidelity',
        () async {
      final now = DateTime.now();

      // Seed sample data
      await db.into(db.entries).insert(
            EntriesCompanion.insert(
              id: 'entry-1',
              userId: 'user-test',
              type: 'journal',
              value: 1.0,
              note: const Value('First Thought'),
              occurredAt: now,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await db.into(db.accounts).insert(
            AccountsCompanion.insert(
              id: 'acc-1',
              name: 'Checking Account',
              type: 'asset',
              subType: const Value('checking'),
              currency: const Value('USD'),
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      await db.into(db.accountBalances).insert(
            AccountBalancesCompanion.insert(
              id: 'bal-1',
              accountId: 'acc-1',
              balance: 1250.0,
              recordedAt: now,
              createdAt: Value(now),
            ),
          );

      await db.into(db.debts).insert(
            DebtsCompanion.insert(
              id: 'debt-1',
              personName: 'Alice',
              type: 'lent',
              initialAmount: 200.0,
              remainingAmount: 200.0,
              createdAt: Value(now),
              updatedAt: Value(now),
            ),
          );

      // Verify statistics
      var stats = await exportService.getDatabaseStatistics();
      expect(stats['entries'], 1);
      expect(stats['accounts'], 1);
      expect(stats['debts'], 1);
      expect(stats['total'], 3);

      // Export to JSON
      final jsonString = await exportService.exportAllDataAsJson();
      final decoded = jsonDecode(jsonString) as Map<String, dynamic>;
      final tables = decoded['tables'] as Map<String, dynamic>;
      expect((tables['entries'] as List).length, 1);
      expect((tables['accounts'] as List).length, 1);
      expect((tables['accountBalances'] as List).length, 1);
      expect((tables['debts'] as List).length, 1);

      // Create second in-memory database and import JSON
      final db2 = AppDatabase(NativeDatabase.memory());
      final exportService2 = DataExportService(db2);

      final importSuccess =
          await exportService2.importDataFromJson(jsonString);
      expect(importSuccess, isTrue);

      final stats2 = await exportService2.getDatabaseStatistics();
      expect(stats2['entries'], 1);
      expect(stats2['accounts'], 1);
      expect(stats2['debts'], 1);
      expect(stats2['total'], 3);

      final entriesInDb2 = await db2.select(db2.entries).get();
      expect(entriesInDb2.first.note, 'First Thought');

      final accountsInDb2 = await db2.select(db2.accounts).get();
      expect(accountsInDb2.first.name, 'Checking Account');

      final balancesInDb2 = await db2.select(db2.accountBalances).get();
      expect(balancesInDb2.first.balance, 1250.0);

      await db2.close();
    });

    test('Import rejects malformed JSON or invalid schema without crashing',
        () async {
      expect(await exportService.importDataFromJson('not-json'), isFalse);
      expect(await exportService.importDataFromJson('{"version": 0}'), isFalse);
      expect(await exportService.importDataFromJson('{"version": 1}'), isFalse);
    });
  });

  group('Security Providers State Tests', () {
    test('AppLockEnabledNotifier toggles enabled state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(appLockEnabledProvider), isFalse);

      container.read(appLockEnabledProvider.notifier).setEnabled(true);
      expect(container.read(appLockEnabledProvider), isTrue);

      container.read(appLockEnabledProvider.notifier).setEnabled(false);
      expect(container.read(appLockEnabledProvider), isFalse);
    });

    test('IsAppLockedNotifier locks and unlocks state', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(isAppLockedProvider), isFalse);

      container.read(isAppLockedProvider.notifier).lock();
      expect(container.read(isAppLockedProvider), isTrue);

      container.read(isAppLockedProvider.notifier).unlock();
      expect(container.read(isAppLockedProvider), isFalse);
    });
  });
}
