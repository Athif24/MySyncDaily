import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_id.dart';
import 'package:sync_daily/features/notifications/domain/reminder_schedule_planner.dart';
import 'package:sync_daily/features/tasks/domain/entities/task.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_recurrence.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_reminder.dart';

/// Membentuk entri riwayat notifikasi dari pengingat yang sudah berbunyi.
///
/// Murni: tidak menyentuh database maupun plugin, sehingga aturan "kapan sebuah
/// kemunculan dianggap pernah dijadwalkan" bisa diuji langsung.
///
/// Aturan anti entri hantu: rekonsiliasi hanya membentuk entri untuk kemunculan
/// yang waktu bunyinya TIDAK lebih awal dari saat pengingat dibuat/diperbarui
/// (waktu simpan pengingat). Dengan begitu tugas yang dibuat dengan waktu yang
/// sudah lewat, atau pengingat yang waktunya diubah ke masa lalu, tidak membuat
/// entri belum dibaca, karena kemunculan itu memang tidak pernah dijadwalkan
/// ([ReminderSchedulePlanner] juga melewati kemunculan yang sudah lewat saat
/// menjadwalkan).
class NotificationHistoryBuilder {
  const NotificationHistoryBuilder._();

  static List<AppNotification> build({
    required List<Task> tasks,
    required Map<String, List<TaskReminder>> remindersByTask,
    required Map<String, TaskRecurrence> recurrenceByTask,
    required DateTime now,
    required Duration lookback,
  }) {
    final entries = <AppNotification>[];
    for (final task in tasks) {
      final reminders = remindersByTask[task.id];
      if (reminders == null || reminders.isEmpty) {
        continue;
      }
      entries.addAll(
        buildForTask(
          task: task,
          reminders: reminders,
          recurrence: recurrenceByTask[task.id],
          now: now,
          lookback: lookback,
        ),
      );
    }
    return entries;
  }

  /// Entri riwayat untuk satu tugas dari kemunculan pengingat yang sudah
  /// berbunyi dalam [lookback] terakhir.
  static List<AppNotification> buildForTask({
    required Task task,
    required List<TaskReminder> reminders,
    required TaskRecurrence? recurrence,
    required DateTime now,
    required Duration lookback,
  }) {
    if (task.isDeleted || reminders.isEmpty) {
      return const [];
    }

    // Tugas selesai tidak menghasilkan jadwal, tetapi kemunculan yang sudah
    // berbunyi SEBELUM diselesaikan tetap harus tercatat. Karena itu
    // rencanakan dengan status "belum selesai" (bayangan), lalu saring dengan
    // waktu selesai.
    final plannedTask = task.status == TaskStatus.done
        ? task.copyWith(status: TaskStatus.todo)
        : task;

    final planned = ReminderSchedulePlanner.plan(
      task: plannedTask,
      reminders: reminders,
      recurrence: recurrence,
      now: now.subtract(lookback),
      window: lookback,
    );

    final reminderById = <String, TaskReminder>{
      for (final reminder in reminders) reminder.id: reminder,
    };
    final cutoff = task.completedAt ?? task.deletedAt;

    final entries = <AppNotification>[];
    for (final occurrence in planned) {
      final reminder = reminderById[occurrence.reminderId];
      if (reminder == null) {
        continue;
      }
      // Anti entri hantu: kemunculan yang waktu bunyinya lebih awal dari saat
      // pengingat dibuat/diperbarui tidak pernah dijadwalkan.
      if (occurrence.fireAt.isBefore(_scheduleInstant(reminder))) {
        continue;
      }
      // Kemunculan setelah tugas diselesaikan/dihapus dibatalkan, jadi tidak
      // dicatat.
      if (cutoff != null && occurrence.fireAt.isAfter(cutoff)) {
        continue;
      }
      final fireAt = occurrence.fireAt.toUtc();
      entries.add(
        AppNotification(
          id: NotificationHistoryId.forReminder(
            taskId: task.id,
            reminderId: occurrence.reminderId,
            occurrence: occurrence.occurrence,
          ),
          type: notificationTypeForTaskType(task.type),
          title: task.title,
          body: AppStrings.reminderNotificationBody(occurrence.offsetMinutes),
          entityType: notificationTaskEntityType,
          entityId: task.id,
          scheduledAt: fireAt,
          isRead: false,
          createdAt: fireAt,
          updatedAt: fireAt,
        ),
      );
    }
    return entries;
  }

  /// Waktu pengingat "terakhir disimpan".
  ///
  /// Dipilih dari pengingat (bukan tugas) karena baris pengingat dibuat ulang
  /// setiap kali form tugas disimpan — jadi waktunya tepat menandai "sejak kapan
  /// pengingat ini ada". `updatedAt` dipakai sebagai pembanding agar tetap benar
  /// bila di masa depan `createdAt` dipertahankan saat pengingat diperbarui.
  /// `updatedAt` tugas sengaja TIDAK dipakai karena berubah pada peristiwa yang
  /// tidak mengubah jadwal (mis. menandai selesai), yang bisa membuang entri sah.
  static DateTime _scheduleInstant(TaskReminder reminder) =>
      reminder.createdAt.isAfter(reminder.updatedAt)
          ? reminder.createdAt
          : reminder.updatedAt;
}

/// Pemetaan tipe item ke tipe notifikasi tersimpan.
NotificationType notificationTypeForTaskType(TaskType type) {
  switch (type) {
    case TaskType.reminder:
      return NotificationType.reminder;
    case TaskType.event:
      return NotificationType.event;
    case TaskType.task:
    case TaskType.milestone:
      return NotificationType.deadline;
  }
}
