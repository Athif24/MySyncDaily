import 'package:sync_daily/features/notifications/domain/reminder_notification_id.dart';
import 'package:sync_daily/features/tasks/domain/entities/task.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_recurrence.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_reminder.dart';
import 'package:sync_daily/features/tasks/domain/recurrence_calculator.dart';

/// Satu kemunculan pengingat yang sudah pasti waktunya dan siap dijadwalkan.
class PlannedReminder {
  final int id;
  final String taskId;
  final String reminderId;
  final int offsetMinutes;

  /// Waktu kemunculan yang jadi dasar (instan apa adanya dari data tugas).
  final DateTime occurrence;

  /// Instan notifikasi harus muncul, sudah dibulatkan ke waktu lokal.
  final DateTime fireAt;

  const PlannedReminder({
    required this.id,
    required this.taskId,
    required this.reminderId,
    required this.offsetMinutes,
    required this.occurrence,
    required this.fireAt,
  });
}

/// Perencana jadwal pengingat. Murni: tidak menyentuh database maupun plugin,
/// hanya mengubah data tugas menjadi daftar jadwal notifikasi.
///
/// Aturan (lihat F8a):
/// - Titik acuan: `startAt` bila ada, jika tidak `dueAt` (sama dengan
///   `TaskDateUtils.reminderTimeFor`).
/// - Item seharian dianggap berbunyi pada jam yang diatur pengguna
///   ([allDayHourMinutes], bawaan 08.00 waktu lokal tanggalnya), lalu
///   dikurangi offset.
/// - Kemunculan yang waktunya sudah lewat tidak dijadwalkan.
/// - Hanya kemunculan dalam [defaultWindow] ke depan yang dijadwalkan.
/// - Maksimum [defaultMaxPerTask] alarm per tugas.
/// - Tugas selesai/dihapus tidak menghasilkan jadwal.
class ReminderSchedulePlanner {
  const ReminderSchedulePlanner._();

  /// Jendela penjadwalan ke depan.
  static const Duration defaultWindow = Duration(days: 30);

  /// Batas jumlah alarm per tugas.
  static const int defaultMaxPerTask = 64;

  static List<PlannedReminder> plan({
    required Task task,
    required List<TaskReminder> reminders,
    TaskRecurrence? recurrence,
    required DateTime now,
    Duration window = defaultWindow,
    int maxPerTask = defaultMaxPerTask,
    int allDayHourMinutes = 480,
  }) {
    if (reminders.isEmpty ||
        task.isDeleted ||
        task.status == TaskStatus.done) {
      return const [];
    }

    final anchor = task.startAt ?? task.dueAt;
    if (anchor == null) {
      return const [];
    }

    final windowEnd = now.add(window);
    final maxOffset = reminders.fold<int>(
      0,
      (largest, reminder) =>
          reminder.offsetMinutes > largest ? reminder.offsetMinutes : largest,
    );

    // Kemunculan diperluas sedikit melewati kedua ujung jendela agar offset
    // besar (mis. 1 hari) tetap ikut dihitung; waktu yang sudah lewat tetap
    // disaring oleh pemeriksaan `fireAt.isBefore(now)`.
    final slack = Duration(minutes: maxOffset);
    final occurrences = recurrence == null
        ? <DateTime>[anchor]
        : RecurrenceCalculator.occurrencesInRange(
            rule: recurrence,
            anchor: anchor,
            from: now.subtract(slack),
            to: windowEnd.add(slack),
          );

    final planned = <PlannedReminder>[];
    final seenIds = <int>{};
    for (final occurrence in occurrences) {
      for (final reminder in reminders) {
        final fireAt = _fireAt(task, occurrence, reminder.offsetMinutes,
            allDayHourMinutes: allDayHourMinutes.clamp(0, 1439));
        if (fireAt.isBefore(now) || fireAt.isAfter(windowEnd)) {
          continue;
        }
        final id = ReminderNotificationId.forOccurrence(
          taskId: task.id,
          reminderId: reminder.id,
          occurrence: occurrence,
        );
        // Jaga-jaga bila dua kunci berbeda menghasilkan ID yang sama: jangan
        // sampai notifikasi saling menimpa tanpa sadar.
        if (!seenIds.add(id)) {
          continue;
        }
        planned.add(PlannedReminder(
          id: id,
          taskId: task.id,
          reminderId: reminder.id,
          offsetMinutes: reminder.offsetMinutes,
          occurrence: occurrence,
          fireAt: fireAt,
        ));
        if (planned.length >= maxPerTask) {
          return _sorted(planned);
        }
      }
    }
    return _sorted(planned);
  }

  /// Waktu notifikasi muncul, dalam waktu lokal perangkat.
  static DateTime _fireAt(Task task, DateTime occurrence, int offsetMinutes,
      {int allDayHourMinutes = 480}) {
    final minutes = allDayHourMinutes.clamp(0, 1439);
    final hour = minutes ~/ 60;
    final minute = minutes % 60;
    final DateTime base;
    if (task.isAllDay) {
      // Komponen tanggal occurrence sudah merupakan tanggal kalender (item
      // seharian disimpan sebagai UTC tengah malam, dan pengulangan bulanan
      // menghasilkan tengah malam lokal). Jangan dikonversi zona waktu.
      base = DateTime(
        occurrence.year,
        occurrence.month,
        occurrence.day,
        hour,
        minute,
      );
    } else {
      base = occurrence.toLocal();
    }
    return base.subtract(Duration(minutes: offsetMinutes));
  }

  static List<PlannedReminder> _sorted(List<PlannedReminder> items) {
    items.sort((a, b) => a.fireAt.compareTo(b.fireAt));
    return items;
  }
}
