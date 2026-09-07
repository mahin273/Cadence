import 'package:flutter_foreground_task/flutter_foreground_task.dart';

/// Top-level callback entrypoint for the background isolate.
@pragma('vm:entry-point')
void startCallback() {
  FlutterForegroundTask.setTaskHandler(CadenceTaskHandler());
}

/// Handler managing lifecycle and data events inside the background service isolate.
class CadenceTaskHandler extends TaskHandler {
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {}

  @override
  void onRepeatEvent(DateTime timestamp) {}

  @override
  Future<void> onDestroy(DateTime timestamp, bool isStoppingTask) async {}

  @override
  void onReceiveData(Object data) {
    if (data is Map<String, dynamic>) {
      final title = data['title'] as String?;
      final text = data['text'] as String?;
      if (title != null || text != null) {
        FlutterForegroundTask.updateService(
          notificationTitle: title,
          notificationText: text,
        );
      }
    }
  }

  @override
  void onNotificationButtonPressed(String id) {
    if (id == 'stop') {
      FlutterForegroundTask.stopService();
    }
  }

  @override
  void onNotificationDismissed() {}
}

/// Service controller managing Android Foreground Service lifecycle.
class CadenceForegroundService {
  static bool _isInitialized = false;

  /// Initialize foreground notification channel and service parameters.
  static void init() {
    if (_isInitialized) return;

    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'cadence_foreground_service',
        channelName: 'Cadence Workout & Activity Tracking',
        channelDescription:
            'Persistent notification to keep sensor streams active in background',
        channelImportance: NotificationChannelImportance.LOW,
        priority: NotificationPriority.LOW,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.repeat(5000),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: false,
        allowWakeLock: true,
        allowWifiLock: false,
      ),
    );

    _isInitialized = true;
  }

  /// Request runtime permissions and launch the persistent foreground service.
  static Future<bool> startService({
    String title = 'Cadence Active Session',
    String text = 'Tracking steps & movement in background...',
  }) async {
    init();

    // Check / request notification permission on Android 13+
    final notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

    if (await FlutterForegroundTask.isRunningService) {
      return true;
    }

    final result = await FlutterForegroundTask.startService(
      serviceId: 256,
      notificationTitle: title,
      notificationText: text,
      callback: startCallback,
    );

    return result is ServiceRequestSuccess;
  }

  /// Update the live notification message.
  static Future<void> updateService({
    String? title,
    required String text,
  }) async {
    if (await FlutterForegroundTask.isRunningService) {
      await FlutterForegroundTask.updateService(
        notificationTitle: title,
        notificationText: text,
      );
    }
  }

  /// Terminate the foreground service and dismiss sticky notification.
  static Future<bool> stopService() async {
    final result = await FlutterForegroundTask.stopService();
    return result is ServiceRequestSuccess;
  }

  /// Check whether the service is actively running.
  static Future<bool> isRunning() async {
    return FlutterForegroundTask.isRunningService;
  }
}
