import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/features/notifications/domain/reminder_notification.dart';
import 'package:sync_daily/features/notifications/domain/reminder_notification_id.dart';
import 'package:sync_daily/features/notifications/domain/reminder_payload.dart';
import 'package:timezone/data/latest_all.dart' as timezone_data;
import 'package:timezone/timezone.dart' as tz;

/// Penangan latar untuk aksi notifikasi.
///
/// Semua aksi dipasang dengan `showsUserInterface: true`, jadi
/// `flutter_local_notifications` mengarahkannya ke isolate utama lewat
/// [LocalReminderScheduler] dan bukan ke isolate latar. Fungsi ini hanya
/// dipakai sebagai syarat plugin (callback latar harus top-level dan
/// `vm:entry-point`), dan sengaja tidak melakukan apa pun agar tidak ada
/// penanganan ganda.
@pragma('vm:entry-point')
void reminderNotificationBackgroundHandler(NotificationResponse response) {}

/// Implementasi [ReminderScheduler] di atas `flutter_local_notifications`.
class LocalReminderScheduler implements ReminderScheduler {
  final FlutterLocalNotificationsPlugin _plugin;

  LocalReminderScheduler({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  static const String _channelId = 'sync_daily_reminders';

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<void> initialize({
    void Function(ReminderResponse response)? onResponse,
  }) async {
    timezone_data.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _plugin.initialize(
      settings: settings,
      onDidReceiveNotificationResponse: (response) {
        final parsed = _toResponse(response);
        if (parsed != null) {
          onResponse?.call(parsed);
        }
      },
      onDidReceiveBackgroundNotificationResponse:
          reminderNotificationBackgroundHandler,
    );
  }

  @override
  Future<ReminderResponse?> launchResponse() async {
    final details = await _plugin.getNotificationAppLaunchDetails();
    if (details == null || !details.didNotificationLaunchApp) {
      return null;
    }
    final response = details.notificationResponse;
    return response == null ? null : _toResponse(response);
  }

  @override
  Future<List<PendingReminder>> pendingReminders() async {
    final pending = await _plugin.pendingNotificationRequests();
    return [
      for (final request in pending) _toPending(request),
    ];
  }

  @override
  Future<void> schedule(ReminderNotification notification) async {
    await _plugin.zonedSchedule(
      id: notification.id,
      title: notification.title,
      body: notification.body,
      scheduledDate: tz.TZDateTime.from(notification.fireAt.toUtc(), tz.UTC),
      notificationDetails: const NotificationDetails(android: _details),
      androidScheduleMode: await _scheduleMode(),
      payload: ReminderPayload(
        taskId: notification.taskId,
        reminderId: notification.reminderId,
        occurrence: notification.occurrence,
        isSnooze: notification.isSnooze,
      ).encode(),
    );
  }

  @override
  Future<void> cancel(int id) => _plugin.cancel(id: id);

  @override
  Future<void> cancelAll() => _plugin.cancelAll();

  @override
  Future<void> scheduleTest({
    Duration delay = const Duration(seconds: 10),
  }) async {
    await schedule(ReminderNotification(
      id: ReminderNotificationId.forTest(),
      taskId: ReminderNotificationId.testTaskId,
      title: AppStrings.notificationTestTitle,
      body: AppStrings.notificationTestBody,
      fireAt: DateTime.now().add(delay),
    ));
  }

  PendingReminder _toPending(PendingNotificationRequest request) {
    final payload = ReminderPayload.tryParse(request.payload);
    return PendingReminder(
      id: request.id,
      taskId: payload?.taskId,
      isSnooze: payload?.isSnooze ?? false,
    );
  }

  ReminderResponse? _toResponse(NotificationResponse response) {
    final payload = ReminderPayload.tryParse(response.payload);
    if (payload == null) {
      return null;
    }
    return ReminderResponse(
      notificationId: response.id ?? 0,
      taskId: payload.taskId,
      reminderId: payload.reminderId,
      occurrence: payload.occurrence,
      isSnooze: payload.isSnooze,
      actionId: response.actionId,
    );
  }

  /// Detail notifikasi yang sama untuk semua pengingat.
  static const AndroidNotificationDetails _details = AndroidNotificationDetails(
    _channelId,
    AppStrings.reminderChannelName,
    channelDescription: AppStrings.reminderChannelDescription,
    importance: Importance.high,
    priority: Priority.high,
    category: AndroidNotificationCategory.reminder,
    actions: [
      AndroidNotificationAction(
        ReminderAction.done,
        AppStrings.notificationActionDone,
        showsUserInterface: true,
        cancelNotification: true,
      ),
      AndroidNotificationAction(
        ReminderAction.snooze,
        AppStrings.notificationActionSnooze,
        showsUserInterface: true,
        cancelNotification: true,
      ),
    ],
  );

  Future<AndroidScheduleMode> _scheduleMode() async {
    final canExact = await _android?.canScheduleExactNotifications();
    // Null (mis. perangkat lama / bukan Android) diperlakukan sebagai boleh,
    // karena pembatasan alarm tepat waktu baru ada sejak Android 12.
    final exact = canExact ?? true;
    return exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
  }
}
