import 'package:flutter/foundation.dart';
import 'package:sync_daily/features/notifications/domain/reminder_synchronizer.dart';
import 'package:sync_daily/features/tasks/domain/entities/task.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_recurrence.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_reminder.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_summary.dart';
import 'package:sync_daily/features/tasks/domain/repositories/task_repository.dart';

/// Membungkus [TaskRepository] supaya setiap perubahan yang memengaruhi
/// pengingat otomatis menyelaraskan jadwal notifikasi.
///
/// Semua operasi baca diteruskan apa adanya. Kegagalan penjadwalan tidak pernah
/// menggagalkan penyimpanan data (mis. izin belum diberikan): cukup dicatat.
class ReminderSyncingTaskRepository implements TaskRepository {
  final TaskRepository _delegate;
  final ReminderSynchronizer _synchronizer;

  ReminderSyncingTaskRepository({
    required TaskRepository delegate,
    required ReminderSynchronizer synchronizer,
  })  : _delegate = delegate,
        _synchronizer = synchronizer;

  @override
  Stream<List<Task>> watchTodayTasks() => _delegate.watchTodayTasks();

  @override
  Stream<List<Task>> watchTasksInRange(DateTime from, DateTime to) =>
      _delegate.watchTasksInRange(from, to);

  @override
  Stream<List<Task>> watchTasksByProject(String projectId) =>
      _delegate.watchTasksByProject(projectId);

  @override
  Stream<List<Task>> watchAllTasks() => _delegate.watchAllTasks();

  @override
  Future<List<Task>> getAllTasks() => _delegate.getAllTasks();

  @override
  Future<Task?> getTask(String id) => _delegate.getTask(id);

  @override
  Stream<TaskSummary> watchSummary({
    DateTime? periodStart,
    DateTime? periodEnd,
    DateTime? today,
  }) =>
      _delegate.watchSummary(
        periodStart: periodStart,
        periodEnd: periodEnd,
        today: today,
      );

  @override
  Future<TaskSummary> getSummary({
    DateTime? periodStart,
    DateTime? periodEnd,
    DateTime? today,
  }) =>
      _delegate.getSummary(
        periodStart: periodStart,
        periodEnd: periodEnd,
        today: today,
      );

  @override
  Future<void> upsertTask(Task task) async {
    await _delegate.upsertTask(task);
    await _sync(() => _synchronizer.syncTask(task.id));
  }

  @override
  Future<void> setStatus(String id, TaskStatus status) async {
    await _delegate.setStatus(id, status);
    await _sync(() => _synchronizer.syncTask(id));
  }

  @override
  Future<List<String>> softDeleteTask(String id) async {
    final deleted = await _delegate.softDeleteTask(id);
    await _sync(() => _synchronizer.cancelTasks(deleted));
    return deleted;
  }

  @override
  Future<void> restoreTasks(List<String> ids) async {
    await _delegate.restoreTasks(ids);
    await _sync(() => _synchronizer.syncTasks(ids));
  }

  @override
  Future<List<TaskReminder>> getReminders(String taskId) =>
      _delegate.getReminders(taskId);

  @override
  Future<List<TaskReminder>> getAllReminders() =>
      _delegate.getAllReminders();

  @override
  Future<void> replaceReminders(
    String taskId,
    List<TaskReminder> reminders,
  ) async {
    await _delegate.replaceReminders(taskId, reminders);
    await _sync(() => _synchronizer.syncTask(taskId));
  }

  @override
  Future<TaskRecurrence?> getRecurrence(String taskId) =>
      _delegate.getRecurrence(taskId);

  @override
  Stream<List<TaskRecurrence>> watchRecurrences() =>
      _delegate.watchRecurrences();

  @override
  Future<List<TaskRecurrence>> getAllRecurrences() =>
      _delegate.getAllRecurrences();

  @override
  Future<void> setRecurrence(String taskId, TaskRecurrence? recurrence) async {
    await _delegate.setRecurrence(taskId, recurrence);
    await _sync(() => _synchronizer.syncTask(taskId));
  }

  Future<void> _sync(Future<void> Function() action) async {
    try {
      await action();
    } catch (error) {
      debugPrint('[SyncDaily] Gagal menyinkronkan pengingat: $error');
    }
  }
}
