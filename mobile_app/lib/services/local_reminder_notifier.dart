import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/utils/device_timezone.dart';
import '../features/reminders/reminder_model.dart';
import '../features/tasks/task_model.dart';
import 'reminder_notifier.dart';

/// Schedules reminder and pending-task notifications on the phone with
/// flutter_local_notifications. They fire even when the app is closed, and
/// on Android they play Liyana's voice (res/raw/liyana_*.ogg).
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

  List<Reminder> _reminders = const [];
  List<Task> _tasks = const [];

  /// Reschedules run one after another, never interleaved.
  Future<void> _queue = Future.value();

  // Android fixes a channel's sound when it is created, so the voice
  // channels have new ids; the old silent "reminders" channel is removed.
  static const _oldChannelId = 'reminders';

  static const _reminderDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'liyana_voice_reminders',
      'Reminders',
      channelDescription: 'Reminders you set with Liyana, read out loud',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('liyana_reminder'),
      category: AndroidNotificationCategory.reminder,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  static const _pendingTasksDetails = NotificationDetails(
    android: AndroidNotificationDetails(
      'liyana_voice_pending_tasks',
      'Pending tasks',
      channelDescription: 'Evening nudge from Liyana about unfinished tasks',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      sound: RawResourceAndroidNotificationSound('liyana_pending_tasks'),
      category: AndroidNotificationCategory.reminder,
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
      // Tapped while the app is running or in the background.
      onDidReceiveNotificationResponse: (_) => notificationOpens.value++,
    );
    _initialized = true;

    // Tapped while the app was closed: it was started by the notification.
    final launch = await _plugin.getNotificationAppLaunchDetails();
    if (launch?.didNotificationLaunchApp ?? false) notificationOpens.value++;

    await _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.deleteNotificationChannel(channelId: _oldChannelId);
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

  Future<void> _enqueue(Future<void> Function() job) {
    final next = _queue.then((_) => job());
    _queue = next.catchError((Object error) {
      // Notifications must never break the reminders or tasks screens.
      debugPrint('Could not schedule notifications: $error');
    });
    return _queue;
  }

  /// Make the phone's pending notifications match the latest reminders
  /// and tasks.
  Future<void> _reschedule() async {
    await _init();
    final now = DateTime.now();
    final planned = [
      ...planNotifications(_reminders, now),
      ...planTaskNudges(_tasks, now),
    ];

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
        notificationDetails: item.kind == NotificationKind.pendingTasks
            ? _pendingTasksDetails
            : _reminderDetails,
        // Inexact needs no special "exact alarm" permission; Android may
        // deliver it a few minutes late to save battery.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      );
    }
  }

  @override
  Future<void> sync(List<Reminder> reminders) {
    _reminders = List.of(reminders);
    return _enqueue(_reschedule);
  }

  @override
  Future<void> syncTasks(List<Task> tasks) {
    _tasks = List.of(tasks);
    return _enqueue(_reschedule);
  }

  @override
  Future<void> cancelAll() {
    _reminders = const [];
    _tasks = const [];
    return _enqueue(() async {
      await _init();
      await _plugin.cancelAllPendingNotifications();
    });
  }
}
