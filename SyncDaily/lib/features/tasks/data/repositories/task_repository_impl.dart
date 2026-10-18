import 'dart:async';

import 'package:sync_daily/core/database/app_database.dart';
import 'package:sync_daily/features/projects/data/daos/projects_dao.dart';
import 'package:sync_daily/features/tasks/data/daos/tasks_dao.dart';
import 'package:sync_daily/features/tasks/data/mappers/task_mapper.dart';
import 'package:sync_daily/features/tasks/domain/entities/task.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_recurrence.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_reminder.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_summary.dart';
import 'package:sync_daily/features/tasks/domain/repositories/task_repository.dart';
import 'package:sync_daily/features/tasks/domain/task_date_utils.dart';
import 'package:sync_daily/features/tasks/domain/task_list_filter.dart';

class TaskRepositoryImpl implements TaskRepository {
  final TasksDao _dao;
  final ProjectsDao _projectsDao;

  TaskRepositoryImpl(this._dao, this._projectsDao);

  @override
  Stream<List<Task>> watchTodayTasks() {
    return _dao.watchActiveTasks().map((rows) {
      final today = DateTime.now();
      return rows
          .map((row) => row.toEntity())
          .where((task) =>
              task.status != TaskStatus.done &&
              TaskDateUtils.isOnDay(task, today))
          .toList();
    });
  }

  @override
  Stream<List<Task>> watchTasksInRange(DateTime from, DateTime to) {
    return _dao.watchActiveTasks().map(
          (rows) => rows
              .map((row) => row.toEntity())
              .where((task) => TaskDateUtils.isInRange(task, from, to))
              .toList(),
        );
  }

  @override
  Stream<List<Task>> watchTasksByProject(String projectId) {
    return _dao
        .watchTasksByProject(projectId)
        .map((rows) => rows.map((row) => row.toEntity()).toList());
  }

  @override
  Stream<List<Task>> watchAllTasks() {
    return _dao
        .watchActiveTasks()
        .map((rows) => rows.map((row) => row.toEntity()).toList());
  }

  @override
  Future<Task?> getTask(String id) async {
    final row = await _dao.getById(id);
    return row?.toEntity();
  }

  @override
  Stream<TaskSummary> watchSummary({
    DateTime? periodStart,
    DateTime? periodEnd,
    DateTime? today,
  }) {
    final reference = today ?? DateTime.now();
    return _combineLatest2<List<TaskRow>, ({int owned, int received}),
        TaskSummary>(
      _dao.watchActiveTasks(),
      _projectsDao.watchRoleCounts(),
      (rows, counts) =>
          _buildSummary(rows, counts, periodStart, periodEnd, reference),
    );
  }

  @override
  Future<TaskSummary> getSummary({
    DateTime? periodStart,
    DateTime? periodEnd,
    DateTime? today,
  }) async {
    final rows = await _dao.watchActiveTasks().first;
    final counts = await _projectsDao.watchRoleCounts().first;

    return _buildSummary(
      rows,
      counts,
      periodStart,
      periodEnd,
      today ?? DateTime.now(),
    );
  }

  TaskSummary _buildSummary(
    List<TaskRow> rows,
    ({int owned, int received}) counts,
    DateTime? periodStart,
    DateTime? periodEnd,
    DateTime today,
  ) {
    final tasks = rows.map((row) => row.toEntity()).toList();

    final todayCount = tasks
        .where((task) =>
            TaskListFilters.matches(task, TaskListFilter.today, today))
        .length;

    final scheduleCount = tasks.where((task) {
      if (task.type != TaskType.event && task.type != TaskType.reminder) {
        return false;
      }
      final reference = TaskDateUtils.referenceDate(task);
      if (reference == null) {
        return false;
      }
      return TaskDateUtils.isWithinPeriod(reference, periodStart, periodEnd);
    }).length;

    final allTasksCount = tasks
        .where((task) => TaskListFilters.matches(task, TaskListFilter.allTasks, today))
        .length;

    return TaskSummary(
      today: todayCount,
      schedule: scheduleCount,
      allTasks: allTasksCount,
      projectsOwned: counts.owned,
      projectsReceived: counts.received,
    );
  }

  @override
  Future<void> upsertTask(Task task) => _dao.upsertTask(task.toCompanion());

  @override
  Future<void> setStatus(String id, TaskStatus status) =>
      _dao.setStatus(id, status, DateTime.now().toUtc());

  @override
  Future<List<String>> softDeleteTask(String id) =>
      _dao.softDeleteTaskCascade(id, DateTime.now().toUtc());

  @override
  Future<void> restoreTasks(List<String> ids) =>
      _dao.restoreTasks(ids, DateTime.now().toUtc());

  @override
  Future<List<TaskReminder>> getReminders(String taskId) async {
    final rows = await _dao.remindersFor(taskId);
    return rows.map((row) => row.toEntity()).toList();
  }

  @override
  Future<List<TaskReminder>> getAllReminders() async {
    final rows = await _dao.allReminders();
    return rows.map((row) => row.toEntity()).toList();
  }

  @override
  Future<void> replaceReminders(
    String taskId,
    List<TaskReminder> reminders,
  ) {
    return _dao.replaceReminders(
      taskId,
      reminders.map((reminder) => reminder.toCompanion()).toList(),
    );
  }

  @override
  Future<TaskRecurrence?> getRecurrence(String taskId) async {
    final row = await _dao.recurrenceFor(taskId);
    return row?.toEntity();
  }

  @override
  Stream<List<TaskRecurrence>> watchRecurrences() {
    return _dao
        .watchRecurrences()
        .map((rows) => rows.map((row) => row.toEntity()).toList());
  }

  @override
  Future<void> setRecurrence(String taskId, TaskRecurrence? recurrence) {
    if (recurrence == null) {
      return _dao.deleteRecurrence(taskId);
    }
    return _dao.upsertRecurrence(recurrence.toCompanion());
  }
}

/// Menggabungkan dua stream: memancarkan nilai baru setiap salah satu stream
/// terbaru berubah. Dipakai agar [TaskRepositoryImpl.watchSummary] reaktif
/// terhadap perubahan tugas maupun proyek tanpa menambah dependensi.
Stream<R> _combineLatest2<A, B, R>(
  Stream<A> a,
  Stream<B> b,
  R Function(A a, B b) combine,
) {
  late StreamController<R> controller;
  A? latestA;
  B? latestB;
  var hasA = false;
  var hasB = false;
  StreamSubscription<A>? subA;
  StreamSubscription<B>? subB;

  void emit() {
    if (hasA && hasB) {
      controller.add(combine(latestA as A, latestB as B));
    }
  }

  controller = StreamController<R>(
    onListen: () {
      subA = a.listen(
        (value) {
          latestA = value;
          hasA = true;
          emit();
        },
        onError: controller.addError,
        onDone: controller.close,
      );
      subB = b.listen(
        (value) {
          latestB = value;
          hasB = true;
          emit();
        },
        onError: controller.addError,
        onDone: controller.close,
      );
    },
    onCancel: () async {
      await subA?.cancel();
      await subB?.cancel();
    },
  );

  return controller.stream;
}
