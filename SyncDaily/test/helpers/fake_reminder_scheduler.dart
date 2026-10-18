import 'package:sync_daily/features/notifications/domain/reminder_notification.dart';
import 'package:sync_daily/features/notifications/domain/reminder_permissions.dart';

/// Penjadwal palsu untuk pengujian.
///
/// Meniru perilaku penting `flutter_local_notifications`:
/// - `schedule` menimpa notifikasi dengan ID sama (tidak menggandakan),
/// - `pendingReminders` mengembalikan yang belum dibatalkan,
/// - semua panggilan dicatat agar bisa diperiksa tes.
class FakeReminderScheduler implements ReminderScheduler {
  final List<ReminderNotification> scheduled = <ReminderNotification>[];
  final List<int> cancelled = <int>[];
  final List<PendingReminder> _pending;

  /// Dipanggil oleh [initialize]; disimpan agar tes bisa memicunya.
  void Function(ReminderResponse response)? onResponse;

  /// Dikembalikan oleh [launchResponse].
  ReminderResponse? launchResponseResult;

  int launchResponseCalls = 0;
  int cancelAllCalls = 0;
  int scheduleTestCalls = 0;

  FakeReminderScheduler({List<PendingReminder>? pending})
      : _pending = [...?pending];

  List<PendingReminder> get pending => List.unmodifiable(_pending);

  @override
  Future<void> initialize({
    void Function(ReminderResponse response)? onResponse,
  }) async {
    this.onResponse = onResponse;
  }

  @override
  Future<ReminderResponse?> launchResponse() async {
    launchResponseCalls++;
    return launchResponseResult;
  }

  @override
  Future<List<PendingReminder>> pendingReminders() async =>
      List.of(_pending);

  @override
  Future<void> schedule(ReminderNotification notification) async {
    scheduled.add(notification);
    _pending
      ..removeWhere((pending) => pending.id == notification.id)
      ..add(PendingReminder(
        id: notification.id,
        taskId: notification.taskId,
        isSnooze: notification.isSnooze,
      ));
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
    _pending.removeWhere((pending) => pending.id == id);
  }

  @override
  Future<void> cancelAll() async {
    cancelAllCalls++;
    _pending.clear();
  }

  @override
  Future<void> scheduleTest({
    Duration delay = const Duration(seconds: 10),
  }) async {
    scheduleTestCalls++;
  }
}

/// Izin palsu untuk pengujian.
class FakeReminderPermissions implements ReminderPermissions {
  bool notificationsEnabledResult;
  bool exactAlarmsResult;

  int openSettingsCalls = 0;
  int requestExactAlarmsCalls = 0;

  FakeReminderPermissions({
    this.notificationsEnabledResult = true,
    this.exactAlarmsResult = true,
  });

  @override
  Future<bool> notificationsEnabled() async => notificationsEnabledResult;

  @override
  Future<bool> ensureNotificationPermission() async =>
      notificationsEnabledResult;

  @override
  Future<bool> canScheduleExactAlarms() async => exactAlarmsResult;

  @override
  Future<void> requestExactAlarmsPermission() async {
    requestExactAlarmsCalls++;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCalls++;
  }
}
