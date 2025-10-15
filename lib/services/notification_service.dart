import 'dart:io' as io;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
// flutter_native_timezone removed due to Android Windows build namespace issues.

class NotificationService {
  NotificationService._internal();
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // initialize timezone
    tz.initializeTimeZones();
    // Attempt to use the local timezone; timezone package will resolve
    // from the environment where possible. If resolution fails, fall back to UTC.
    try {
      final local = tz.local;
      // Accessing tz.local triggers initialization in many environments;
      // if it throws, fall back below.
      tz.setLocalLocation(local);
    } catch (e) {
      tz.setLocalLocation(tz.getLocation('UTC'));
    }

    const android = AndroidInitializationSettings('@mipmap/ic_launcher');
    const ios = DarwinInitializationSettings();
    // Windows initialization settings are required when targeting Windows.
    final windows = io.Platform.isWindows
        ? const WindowsInitializationSettings(
            appName: 'rto_app',
            appUserModelId: 'com.rohit.rto_app',
            guid: '00000000-0000-0000-0000-000000000000',
          )
        : null;

    await _plugin.initialize(
      InitializationSettings(android: android, iOS: ios, windows: windows),
    );
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final scheduledTZ = tz.TZDateTime.from(scheduledDate, tz.local);
    if (scheduledTZ.isBefore(tz.TZDateTime.now(tz.local))) return;

    await _plugin.zonedSchedule(
      id,
      title,
      body,
      scheduledTZ,
      NotificationDetails(
        android: AndroidNotificationDetails(
          'rto_channel',
          'RTO Notifications',
          channelDescription: 'Notifications for registration followups',
          importance: Importance.max,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      ),
      // Use the simplest overload to maximize cross-platform compatibility.
      // androidScheduleMode is required by the plugin API; use exact scheduling.
      androidScheduleMode: AndroidScheduleMode.exact,
    );
  }

  Future<void> cancelNotification(int id) async {
    await _plugin.cancel(id);
  }
}
