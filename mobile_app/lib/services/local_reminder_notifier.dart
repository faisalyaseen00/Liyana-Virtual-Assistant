import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/device_timezone.dart';
import '../features/reminders/reminder_model.dart';
import 'reminder_notifier.dart';

/// Schedules reminder notifications on the phone with
/// flutter_local_notifications. They fire even when the app is closed.
class LocalReminderNotifier implements ReminderNotifier {
  LocalReminderNotifier._();

  /// Returns a working notifier on Android, iOS and macOS, and a no-op one
  /// everywhere else (browsers and these desktop plugins can't schedule).
  static ReminderNotifier create() {
    if (kIsWeb) return NoopReminderNotifier();
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
      case TargetPlatform.iOS:
      case TargetPlatform.macOS:
        return LocalReminderNotifier._();
      default:
        return NoopReminderNotifier();
    }
  }

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  bool _initialized = false;
  bool _permissionAsked = false;

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'reminders',
      'Reminders',
      channelDescription: 'Reminders you set with Liyana',
      importance: Importance.high,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  Future<void> _init() async {
    if (_initialized) return;

    tz_data.initializeTimeZones();
    final zone = await deviceTimezone();
    try {
      if (zone != null) tz.setLocalLocation(tz.getLocation(zone));
    } catch (_) {
      // Unknown zone name: keep the timezone package's default (UTC).
    }

    // Permissions are asked later, the first time there is something to
    // schedule, rather than on app start.
    const darwin = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: AndroidInitializationSettings('@mipmap/ic_launcher'),
        iOS: darwin,
        macOS: darwin,
      ),
    );
    _initialized = true;
  }

  Future<void> _askPermissionOnce() async {
    if (_permissionAsked) return;
    _permissionAsked = true;

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.requestNotificationsPermission();
    await _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
    await _plugin
        .resolvePlatformSpecificImplementation<
          MacOSFlutterLocalNotificationsPlugin
        >()
        ?.requestPermissions(alert: true, badge: true, sound: true);
  }

  @override
  Future<void> sync(List<Reminder> reminders) async {
    try {
      await _init();
      final planned = planNotifications(reminders, DateTime.now());

      // Only pending (not yet shown) notifications are replaced, so ones
      // already in the notification shade stay there.
      await _plugin.cancelAllPendingNotifications();
      if (planned.isEmpty) return;

      await _askPermissionOnce();

      for (final item in planned) {
        await _plugin.zonedSchedule(
          id: item.id,
          title: item.title,
          body: item.body,
          scheduledDate: tz.TZDateTime.from(item.at, tz.local),
          notificationDetails: _details,
          // Inexact needs no special "exact alarm" permission; Android may
          // deliver it a few minutes late to save battery.
          androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        );
      }
    } catch (error) {
      // Notifications must never break the reminders screen.
      debugPrint('Could not schedule reminder notifications: $error');
    }
  }

  @override
  Future<void> cancelAll() async {
    try {
      await _init();
      await _plugin.cancelAllPendingNotifications();
    } catch (error) {
      debugPrint('Could not cancel reminder notifications: $error');
    }
  }
}
