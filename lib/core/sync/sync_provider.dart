import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../database/database_provider.dart';
import '../supabase/auth_provider.dart';
import 'sync_service.dart';
import 'sync_state.dart';

/// Provider exposing the core SyncService instance.
final syncServiceProvider = Provider<SyncService>((ref) {
  final db = ref.watch(appDatabaseProvider);
  final client = ref.watch(supabaseClientProvider);
  return SyncService(db: db, client: client);
});

/// Reactive stream provider for count of unsynced entries waiting in SQLite.
final unsyncedEntriesCountProvider = StreamProvider<int>((ref) {
  final db = ref.watch(appDatabaseProvider);
  return db.watchUnsyncedCount();
});

/// Notifier managing synchronization state, triggers, and network listeners.
class SyncNotifier extends Notifier<SyncInfo> {
  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;

  @override
  SyncInfo build() {
    ref.onDispose(() {
      _connectivitySub?.cancel();
    });

    _listenToConnectivity();

    return const SyncInfo();
  }

  void _listenToConnectivity() {
    try {
      _connectivitySub = Connectivity().onConnectivityChanged.listen(
        (results) {
          final isOnline = results.any((r) => r != ConnectivityResult.none);
          if (isOnline) {
            syncNow();
          } else {
            state = state.copyWith(
              status: SyncStatus.offline,
              message: 'Offline (no internet connection)',
            );
          }
        },
        onError: (_) {
          // Gracefully suppress platform errors in headless/test environments
        },
      );
    } catch (_) {
      // Platform channels may not exist in pure test harnesses
    }
  }

  /// Trigger manual synchronization.
  Future<void> syncNow() async {
    if (state.status == SyncStatus.syncing) return;

    final userId = ref.read(activeUserIdProvider);
    final service = ref.read(syncServiceProvider);

    state = state.copyWith(
      status: SyncStatus.syncing,
      message: 'Synchronizing with cloud...',
    );

    final result = await service.synchronize(
      userId: userId,
      lastSyncedAt: state.lastSyncedAt,
    );

    state = result;
  }
}

/// Main riverpod provider for sync engine state.
final syncNotifierProvider =
    NotifierProvider<SyncNotifier, SyncInfo>(() => SyncNotifier());
