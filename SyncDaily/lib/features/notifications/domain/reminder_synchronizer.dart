import 'package:flutter/foundation.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/features/notifications/domain/reminder_notification.dart';
import 'package:sync_daily/features/notifications/domain/reminder_notification_id.dart';
import 'package:sync_daily/features/notifications/domain/reminder_schedule_planner.dart';
import 'package:sync_daily/features/tasks/domain/entities/task.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/domain/repositories/task_repository.dart';

/// Menjaga jadwal notifikasi pengingat tetap sesuai keadaan tugas.
///
/// Dipanggil dari [ReminderSyncingTaskRepository] setelah setiap perubahan
/// tugas, dan dari siklus hidup aplikasi (`resyncAll`) saat aplikasi dibuka
/// atau dilanjutkan.
///
/// Sinkronisasi satu tugas bersifat idempoten:
/// 1. SEMUA jadwal yang diinginkan dipasang ulang lewat `zonedSchedule`. ID
///    deterministik membuat pemasangan ulang hanya menimpa, bukan
///    menggandakan. Ini penting karena cache plugin bisa masih menganggap
///    alarm tertunda walau alarm di sistem sudah hilang (mis. setelah
///    "Hentikan paksa" atau dibersihkan sistem); kalau yang sudah ada di
///    daftar tertunda dilewati, alarm hilang itu tidak akan pernah dipasang
///    ulang.
/// 2. Hanya notifikasi tertunda yang sudah tidak diinginkan yang dibatalkan.
///    Notifikasi tunda tetap dibiarkan selama tugasnya masih aktif.
class ReminderSynchronizer {
  final TaskRepository _taskRepository;
  final ReminderScheduler _scheduler;
  final DateTime Function() _now;
  final Duration _window;
  final int _maxPerTask;
  final Duration _minResyncInterval;

  DateTime? _lastResyncAt;
  bool _resyncInFlight = false;

  ReminderSynchronizer({
    required TaskRepository taskRepository,
    required ReminderScheduler scheduler,
    DateTime Function()? now,
    Duration window = ReminderSchedulePlanner.defaultWindow,
    int maxPerTask = ReminderSchedulePlanner.defaultMaxPerTask,
    Duration minResyncInterval = const Duration(seconds: 5),
  })  : _taskRepository = taskRepository,
        _scheduler = scheduler,
        _now = now ?? DateTime.now,
        _window = window,
        _maxPerTask = maxPerTask,
        _minResyncInterval = minResyncInterval;

  /// Menyelaraskan notifikasi untuk satu tugas.
  Future<void> syncTask(String taskId) async {
    final task = await _taskRepository.getTask(taskId);
    // Tugas yang hilang/dihapus/selesai tidak punya jadwal diinginkan, dan
    // seluruh notifikasinya (termasuk tunda) dibatalkan.
    final activeTask =
        (task == null || task.isDeleted || task.status == TaskStatus.done)
            ? null
            : task;
    final cancelAll = activeTask == null;

    var desired = const <PlannedReminder>[];
    if (activeTask != null) {
      final reminders = await _taskRepository.getReminders(taskId);
      if (reminders.isNotEmpty) {
        final recurrence = await _taskRepository.getRecurrence(taskId);
        desired = ReminderSchedulePlanner.plan(
          task: activeTask,
          reminders: reminders,
          recurrence: recurrence,
          now: _now(),
          window: _window,
          maxPerTask: _maxPerTask,
        );
      }
    }

    final pending = (await _scheduler.pendingReminders())
        .where((pending) => pending.taskId == taskId)
        .toList(growable: false);

    // 1) Pasang ulang SEMUA jadwal yang diinginkan (idempoten).
    if (activeTask != null) {
      for (final planned in desired) {
        await _scheduler.schedule(_toNotification(planned, activeTask));
      }
    }

    // 2) Batalkan hanya yang sudah tidak diinginkan.
    final desiredIds = desired.map((planned) => planned.id).toSet();
    for (final pendingReminder in pending) {
      final shouldCancel = cancelAll ||
          (!pendingReminder.isSnooze && !desiredIds.contains(pendingReminder.id));
      if (shouldCancel) {
        await _scheduler.cancel(pendingReminder.id);
      }
    }
  }

  Future<void> syncTasks(Iterable<String> taskIds) async {
    for (final taskId in taskIds) {
      await syncTask(taskId);
    }
  }

  /// Membatalkan seluruh notifikasi sebuah tugas (dipakai saat menghapus).
  Future<void> cancelTask(String taskId) async {
    final pending = (await _scheduler.pendingReminders())
        .where((pending) => pending.taskId == taskId);
    for (final pendingReminder in pending) {
      await _scheduler.cancel(pendingReminder.id);
    }
  }

  Future<void> cancelTasks(Iterable<String> taskIds) async {
    for (final taskId in taskIds) {
      await cancelTask(taskId);
    }
  }

  /// Menjadwalkan ulang notifikasi tunda.
  Future<void> snooze(
    String taskId, {
    Duration delay = const Duration(minutes: 10),
  }) async {
    final task = await _taskRepository.getTask(taskId);
    if (task == null || task.isDeleted || task.status == TaskStatus.done) {
      return;
    }
    final fireAt = _now().add(delay);
    await _scheduler.schedule(ReminderNotification(
      id: ReminderNotificationId.forSnooze(taskId: taskId),
      taskId: taskId,
      title: task.title,
      body: AppStrings.notificationSnoozedBody,
      fireAt: fireAt,
      isSnooze: true,
    ));
  }

  /// Menyelaraskan semua tugas yang relevan.
  ///
  /// Hanya memproses tugas yang punya pengingat (atau yang masih menyisakan
  /// notifikasi tertunda), supaya tidak membaca seluruh tugas tiap kali
  /// aplikasi dibuka. Dibatasi frekuensinya ([_minResyncInterval]) dan tidak
  /// menumpuk saat sudah ada sinkronisasi berjalan.
  Future<void> resyncAll({bool force = false}) async {
    if (_resyncInFlight) {
      return;
    }
    final now = _now();
    final last = _lastResyncAt;
    if (!force && last != null && now.difference(last) < _minResyncInterval) {
      return;
    }

    _resyncInFlight = true;
    try {
      final taskIds = <String>{};
      for (final reminder in await _taskRepository.getAllReminders()) {
        taskIds.add(reminder.taskId);
      }
      for (final pending in await _scheduler.pendingReminders()) {
        final taskId = pending.taskId;
        // Lewati notifikasi uji agar tidak ikut dibatalkan.
        if (taskId != null && taskId != ReminderNotificationId.testTaskId) {
          taskIds.add(taskId);
        }
      }
      for (final taskId in taskIds) {
        await syncTask(taskId);
      }
      _lastResyncAt = now;
    } catch (error) {
      debugPrint('[SyncDaily] Gagal menyelaraskan pengingat: $error');
    } finally {
      _resyncInFlight = false;
    }
  }

  ReminderNotification _toNotification(PlannedReminder planned, Task task) {
    return ReminderNotification(
      id: planned.id,
      taskId: planned.taskId,
      reminderId: planned.reminderId,
      occurrence: planned.occurrence,
      title: task.title,
      body: AppStrings.reminderNotificationBody(planned.offsetMinutes),
      fireAt: planned.fireAt,
    );
  }
}
