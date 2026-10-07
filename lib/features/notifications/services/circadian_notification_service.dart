import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import '../../../../core/theme/circadian_theme.dart';
import '../../../../core/database/app_database.dart';

/// Service managing circadian-aware, contextual local device notifications.
/// Never sends generic interval spam; all alerts are paced against SQLite state.
class CircadianNotificationService {
  final FlutterLocalNotificationsPlugin _notificationsPlugin;
  final AppDatabase db;

  static const String channelId = 'cadence_circadian_channel';
  static const String channelName = 'Circadian & Paced Nudges';
  static const String channelDesc =
      'Contextual paced hydration, circadian phase transitions, and focus recovery alerts';

  CircadianNotificationService({
    FlutterLocalNotificationsPlugin? notificationsPlugin,
    required this.db,
  }) : _notificationsPlugin =
            notificationsPlugin ?? FlutterLocalNotificationsPlugin();

  bool _isInitialized = false;

  /// Initializes the local notification plugin and registers Android notification channels.
  Future<bool> initialize() async {
    if (_isInitialized) return true;

    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const linuxSettings = LinuxInitializationSettings(
      defaultActionName: 'Open Cadence',
    );

    const initSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
      linux: linuxSettings,
    );

    try {
      final initialized = await _notificationsPlugin.initialize(
        settings: initSettings,
      );

      // Create Android Notification Channel
      final androidImplementation = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImplementation != null) {
        await androidImplementation.createNotificationChannel(
          const AndroidNotificationChannel(
            channelId,
            channelName,
            description: channelDesc,
            importance: Importance.high,
          ),
        );
      }

      _isInitialized = initialized ?? false;
      return _isInitialized;
    } catch (e) {
      debugPrint('Failed to initialize local notifications: $e');
      return false;
    }
  }

  /// Request runtime permissions for notifications on Android 13+ & iOS.
  Future<bool> requestPermission() async {
    try {
      final androidImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();
      if (androidImpl != null) {
        final granted = await androidImpl.requestNotificationsPermission();
        return granted ?? false;
      }

      final iosImpl = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              IOSFlutterLocalNotificationsPlugin>();
      if (iosImpl != null) {
        final granted = await iosImpl.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );
        return granted ?? false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Pure helper: calculate expected hydration pace and deficit.
  ({bool isBehind, double expectedGlasses, double deficit}) calculateHydrationPace({
    required double currentGlasses,
    required int currentHour,
    int targetGlasses = 8,
  }) {
    // Active daylight waking hours: 8:00 AM (8) to 20:00 PM (20) -> 12 hours
    if (currentHour < 8) {
      return (isBehind: false, expectedGlasses: 0.0, deficit: 0.0);
    }

    final double expected;
    if (currentHour >= 20) {
      expected = targetGlasses.toDouble();
    } else {
      final hoursPassed = (currentHour - 8) + 1;
      expected = (hoursPassed / 13.0) * targetGlasses;
    }

    final deficit = expected - currentGlasses;
    final isBehind = deficit >= 1.0;

    return (
      isBehind: isBehind,
      expectedGlasses: double.parse(expected.toStringAsFixed(1)),
      deficit: double.parse(deficit.toStringAsFixed(1)),
    );
  }

  /// Evaluates today's actual SQLite hydration logs against the circadian pace.
  /// If behind target by at least 1 glass, delivers a gentle paced nudge.
  Future<bool> checkAndTriggerPacedHydrationNudge({
    DateTime? now,
    int targetGlasses = 8,
  }) async {
    final currentTime = now ?? DateTime.now();
    final startOfDay = DateTime(currentTime.year, currentTime.month, currentTime.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    // Fetch water entries from database
    final entries = await (db.select(db.entries)
          ..where((tbl) =>
              tbl.type.equals('water') &
              tbl.occurredAt.isBiggerOrEqualValue(startOfDay) &
              tbl.occurredAt.isSmallerThanValue(endOfDay) &
              tbl.isDeleted.equals(false)))
        .get();

    double totalGlasses = 0.0;
    for (final e in entries) {
      totalGlasses += e.value;
    }

    final pace = calculateHydrationPace(
      currentGlasses: totalGlasses,
      currentHour: currentTime.hour,
      targetGlasses: targetGlasses,
    );

    if (pace.isBehind) {
      await showNotification(
        id: 101,
        title: 'Paced Hydration Nudge',
        body:
            'Behind target (${totalGlasses.toStringAsFixed(0)}/${pace.expectedGlasses.round()} glasses). Rehydrate for afternoon alertness and circadian clarity.',
        payload: 'domain=water&glasses=$totalGlasses',
      );
      return true;
    }

    return false;
  }

  /// Triggers a circadian phase transition alert with biological context.
  Future<void> triggerCircadianPhaseNudge(CircadianPhase phase) async {
    final String title;
    final String body;

    switch (phase) {
      case CircadianPhase.dawn:
        title = 'Dawn Phase Active';
        body =
            'Natural morning light window open. Hydrate and review your daily launchpad routines.';
        break;
      case CircadianPhase.day:
        title = 'Daylight Peak Active';
        body =
            'Peak cognitive alertness window. Ideal phase for deep focus sessions.';
        break;
      case CircadianPhase.dusk:
        title = 'Dusk Transition Active';
        body =
            'Body temperature is dropping. Dim screens and transition into restorative wind-down.';
        break;
      case CircadianPhase.night:
        title = 'Night Phase Active';
        body =
            'Melatonin secretion active. Restrict bright device screens for deep sleep recovery.';
        break;
    }

    await showNotification(
      id: 102,
      title: title,
      body: body,
      payload: 'domain=circadian&phase=${phase.name}',
    );
  }

  /// Triggers a recovery nudge after a completed focus session.
  Future<void> triggerFocusRecoveryNudge({required int minutes}) async {
    await showNotification(
      id: 103,
      title: 'Deep Work Concluded ($minutes min)',
      body:
          'Excellent concentration block. Stand up, rest your eyes on distant horizon, and drink water.',
      payload: 'domain=focus&duration=$minutes',
    );
  }

  /// Sends an immediate test notification to confirm device notification channel works.
  Future<void> showTestNudge() async {
    await showNotification(
      id: 104,
      title: 'Cadence Circadian Nudge',
      body:
          'Notification system active. Paced hydration and circadian transitions are calibrated with local SQLite.',
      payload: 'domain=test',
    );
  }

  /// Low-level notification dispatcher.
  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    await initialize();

    const androidDetails = AndroidNotificationDetails(
      channelId,
      channelName,
      channelDescription: channelDesc,
      importance: Importance.high,
      priority: Priority.high,
      showWhen: true,
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );

    try {
      await _notificationsPlugin.show(
        id: id,
        title: title,
        body: body,
        notificationDetails: notificationDetails,
        payload: payload,
      );
    } catch (e) {
      debugPrint('Error showing local notification: $e');
    }
  }
}
