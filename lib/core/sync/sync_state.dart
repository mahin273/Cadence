enum SyncStatus {
  idle,
  syncing,
  synced,
  offline,
  error,
}

/// Holds snapshot state for the synchronization engine.
class SyncInfo {
  final SyncStatus status;
  final DateTime? lastSyncedAt;
  final String? message;
  final int pushedCount;
  final int pulledCount;

  const SyncInfo({
    this.status = SyncStatus.idle,
    this.lastSyncedAt,
    this.message,
    this.pushedCount = 0,
    this.pulledCount = 0,
  });

  SyncInfo copyWith({
    SyncStatus? status,
    DateTime? lastSyncedAt,
    String? message,
    int? pushedCount,
    int? pulledCount,
  }) {
    return SyncInfo(
      status: status ?? this.status,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      message: message,
      pushedCount: pushedCount ?? this.pushedCount,
      pulledCount: pulledCount ?? this.pulledCount,
    );
  }

  @override
  String toString() =>
      'SyncInfo(status: $status, lastSyncedAt: $lastSyncedAt, pushed: $pushedCount, pulled: $pulledCount, message: $message)';
}
