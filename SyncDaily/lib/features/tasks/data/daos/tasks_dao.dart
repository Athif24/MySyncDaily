import 'package:drift/drift.dart';
import 'package:sync_daily/core/database/app_database.dart';
import 'package:sync_daily/features/tasks/data/database/task_recurrences_table.dart';
import 'package:sync_daily/features/tasks/data/database/task_reminders_table.dart';
import 'package:sync_daily/features/tasks/data/database/tasks_table.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';

part 'tasks_dao.g.dart';

@DriftAccessor(tables: [Tasks, TaskReminders, TaskRecurrences])
class TasksDao extends DatabaseAccessor<AppDatabase> with _$TasksDaoMixin {
  TasksDao(super.db);

  Stream<List<TaskRow>> watchActiveTasks() {
    return (select(tasks)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.dueAt)]))
        .watch();
  }

  /// Sama dengan [watchActiveTasks] tetapi sekali baca (bukan stream).
  ///
  /// Dipakai pekerjaan latar non-reaktif (mis. rekonsiliasi riwayat notifikasi)
  /// supaya tidak membuka query stream yang meninggalkan timer saat dibatalkan
  /// di dalam `flutter_test`.
  Future<List<TaskRow>> allActiveTasks() {
    return (select(tasks)
          ..where((t) => t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.dueAt)]))
        .get();
  }

  Stream<List<TaskRow>> watchTasksByProject(String projectId) {
    return (select(tasks)
          ..where((t) => t.projectId.equals(projectId) & t.deletedAt.isNull())
          ..orderBy([(t) => OrderingTerm.asc(t.dueAt)]))
        .watch();
  }

  Future<TaskRow?> getById(String id) {
    return (select(tasks)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  Future<void> upsertTask(TasksCompanion companion) {
    return into(tasks).insertOnConflictUpdate(companion);
  }

  Future<void> setStatus(String id, TaskStatus status, DateTime now) {
    return (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        status: Value(status),
        completedAt: Value(status == TaskStatus.done ? now : null),
        updatedAt: Value(now),
      ),
    );
  }

  /// Soft delete tugas beserta seluruh sub-task turunannya. Mengembalikan id
  /// seluruh baris yang terhapus (induk + turunan) agar bisa dipulihkan lewat
  /// [restoreTasks].
  Future<List<String>> softDeleteTaskCascade(String id, DateTime now) async {
    final deleted = <String>[id];
    await (update(tasks)..where((t) => t.id.equals(id))).write(
      TasksCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
    final children = await (select(tasks)
          ..where((t) => t.parentTaskId.equals(id) & t.deletedAt.isNull()))
        .get();
    for (final child in children) {
      deleted.addAll(await softDeleteTaskCascade(child.id, now));
    }
    return deleted;
  }

  /// Memulihkan tugas yang sebelumnya di-soft-delete (mengosongkan `deletedAt`).
  Future<void> restoreTasks(List<String> ids, DateTime now) async {
    if (ids.isEmpty) {
      return;
    }
    await (update(tasks)..where((t) => t.id.isIn(ids))).write(
      TasksCompanion(
        deletedAt: const Value(null),
        updatedAt: Value(now),
      ),
    );
  }

  Future<List<TaskReminderRow>> remindersFor(String taskId) {
    return (select(taskReminders)
          ..where((r) => r.taskId.equals(taskId))
          ..orderBy([(r) => OrderingTerm.asc(r.offsetMinutes)]))
        .get();
  }

  /// Seluruh pengingat dari semua tugas. Dipakai sinkronisasi jadwal notifikasi
  /// agar hanya tugas yang punya pengingat yang diproses.
  Future<List<TaskReminderRow>> allReminders() {
    return select(taskReminders).get();
  }

  Future<void> replaceReminders(
    String taskId,
    List<TaskRemindersCompanion> reminders,
  ) async {
    await (delete(taskReminders)..where((r) => r.taskId.equals(taskId))).go();
    await batch((b) => b.insertAll(taskReminders, reminders));
  }

  Future<TaskRecurrenceRow?> recurrenceFor(String taskId) {
    return (select(taskRecurrences)..where((r) => r.taskId.equals(taskId)))
        .getSingleOrNull();
  }

  /// Aturan pengulangan milik item yang belum dihapus.
  ///
  /// Dipakai Kalender untuk memperluas kemunculan tanpa menulis salinan ke
  /// database. Query sub-nya menyaring item yang sudah di-soft-delete.
  Stream<List<TaskRecurrenceRow>> watchRecurrences() {
    final activeTaskIds = selectOnly(tasks)
      ..addColumns([tasks.id])
      ..where(tasks.deletedAt.isNull());
    return (select(taskRecurrences)
          ..where((r) => r.taskId.isInQuery(activeTaskIds)))
        .watch();
  }

  /// Sama dengan [watchRecurrences] tetapi sekali baca (bukan stream).
  Future<List<TaskRecurrenceRow>> allRecurrences() {
    final activeTaskIds = selectOnly(tasks)
      ..addColumns([tasks.id])
      ..where(tasks.deletedAt.isNull());
    return (select(taskRecurrences)
          ..where((r) => r.taskId.isInQuery(activeTaskIds)))
        .get();
  }

  Future<void> upsertRecurrence(TaskRecurrencesCompanion companion) {
    return into(taskRecurrences).insertOnConflictUpdate(companion);
  }

  Future<void> deleteRecurrence(String taskId) {
    return (delete(taskRecurrences)..where((r) => r.taskId.equals(taskId)))
        .go();
  }
}
