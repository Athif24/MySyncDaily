import 'package:sync_daily/features/tasks/domain/entities/task.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_recurrence.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_reminder.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_summary.dart';

/// Menyembunyikan sumber data (Drift) dari UI. Implementasi ada di lapisan data
/// sehingga sinkronisasi server bisa ditambahkan tanpa mengubah UI.
abstract class TaskRepository {
  /// Item semua tipe yang tanggal acuannya hari ini, belum selesai, belum
  /// dihapus.
  Stream<List<Task>> watchTodayTasks();

  /// Item yang tanggal acuannya berada dalam `[from, to]` (inklusif), belum
  /// dihapus.
  Stream<List<Task>> watchTasksInRange(DateTime from, DateTime to);

  /// Item milik satu proyek, belum dihapus.
  Stream<List<Task>> watchTasksByProject(String projectId);

  /// Semua item belum dihapus (dipakai untuk sub-task dan daftar umum).
  Stream<List<Task>> watchAllTasks();

  Future<Task?> getTask(String id);

  /// Versi reaktif dari [getSummary] untuk Beranda. Memancarkan ulang setiap
  /// ada perubahan tugas maupun proyek.
  ///
  /// `periodStart`/`periodEnd` hanya memengaruhi hitungan jadwal; `null`
  /// berarti tanpa batas (mis. filter "Semua"). Hari ini, semua tugas, dan
  /// jumlah proyek tidak terpengaruh periode.
  ///
  /// `today` adalah waktu acuan untuk hitungan "hari ini" (biasanya jam yang
  /// diinjeksi pemanggil agar bisa diuji); `null` berarti waktu sistem.
  Stream<TaskSummary> watchSummary({
    DateTime? periodStart,
    DateTime? periodEnd,
    DateTime? today,
  });

  Future<TaskSummary> getSummary({
    DateTime? periodStart,
    DateTime? periodEnd,
    DateTime? today,
  });

  Future<void> upsertTask(Task task);

  /// Mengubah status. Saat menjadi [TaskStatus.done], `completedAt` diisi;
  /// saat berubah dari done, `completedAt` dikosongkan.
  Future<void> setStatus(String id, TaskStatus status);

  /// Soft delete tugas beserta seluruh sub-task turunannya. Mengembalikan id
  /// seluruh baris yang ikut terhapus (induk + turunan) agar bisa dipulihkan
  /// lewat [restoreTasks] (aksi "Urungkan").
  Future<List<String>> softDeleteTask(String id);

  /// Memulihkan tugas (dan sub-task) yang sebelumnya ter-soft-delete.
  Future<void> restoreTasks(List<String> ids);

  Future<List<TaskReminder>> getReminders(String taskId);

  /// Seluruh pengingat dari semua tugas (dipakai sinkronisasi jadwal notifikasi
  /// agar hanya tugas yang punya pengingat yang diproses).
  Future<List<TaskReminder>> getAllReminders();

  /// Mengganti seluruh daftar pengingat milik tugas.
  Future<void> replaceReminders(String taskId, List<TaskReminder> reminders);

  Future<TaskRecurrence?> getRecurrence(String taskId);

  /// Semua aturan pengulangan milik item yang belum dihapus (dipakai Kalender
  /// untuk memperluas kemunculan tanpa menulis salinan ke database).
  Stream<List<TaskRecurrence>> watchRecurrences();

  /// Menyimpan aturan pengulangan. Mengirim `null` menghapus aturan.
  Future<void> setRecurrence(String taskId, TaskRecurrence? recurrence);
}
