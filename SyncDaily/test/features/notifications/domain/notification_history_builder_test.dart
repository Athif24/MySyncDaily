import 'package:flutter_test/flutter_test.dart';
import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_builder.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_id.dart';
import 'package:sync_daily/features/tasks/domain/entities/task.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_reminder.dart';

/// Aturan anti entri hantu: entri riwayat hanya dibentuk untuk kemunculan yang
/// waktu bunyinya TIDAK lebih awal dari saat pengingat disimpan.
void main() {
  // Semua instan UTC supaya perbandingan (yang bersifat absolut) dan nilai jam
  // yang diperiksa tidak bergantung zona waktu perangkat.
  final now = DateTime.utc(2026, 10, 15, 12);

  Task task({
    String id = 't1',
    TaskType type = TaskType.task,
    TaskStatus status = TaskStatus.todo,
    DateTime? startAt,
    DateTime? dueAt,
    DateTime? completedAt,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Task(
      id: id,
      title: 'Rapat tim',
      type: type,
      status: status,
      startAt: startAt,
      dueAt: dueAt,
      completedAt: completedAt,
      createdAt: createdAt ?? DateTime.utc(2026, 1, 1),
      updatedAt: updatedAt ?? DateTime.utc(2026, 1, 1),
    );
  }

  TaskReminder reminder({
    String id = 'r1',
    int offsetMinutes = 0,
    DateTime? savedAt,
  }) {
    final saved = savedAt ?? DateTime.utc(2026, 1, 1);
    return TaskReminder(
      id: id,
      taskId: 't1',
      offsetMinutes: offsetMinutes,
      createdAt: saved,
      updatedAt: saved,
    );
  }

  List<AppNotification> buildFor(
    Task subject, {
    List<TaskReminder>? reminders,
  }) {
    return NotificationHistoryBuilder.buildForTask(
      task: subject,
      reminders: reminders ?? [reminder()],
      recurrence: null,
      now: now,
      lookback: const Duration(days: 7),
    );
  }

  test('kemunculan yang sudah berbunyi setelah pengingat disimpan membentuk '
      'entri', () {
    final entries = buildFor(
      task(dueAt: DateTime.utc(2026, 10, 15, 9)),
      reminders: [reminder(savedAt: DateTime.utc(2026, 10, 14))],
    );

    expect(entries, hasLength(1));
    final entry = entries.single;
    expect(entry.title, 'Rapat tim');
    expect(entry.type, NotificationType.deadline);
    expect(entry.entityType, notificationTaskEntityType);
    expect(entry.entityId, 't1');
    expect(entry.isRead, isFalse);
    expect(entry.createdAt, DateTime.utc(2026, 10, 15, 9));
    expect(
      entry.id,
      NotificationHistoryId.forReminder(
        taskId: 't1',
        reminderId: 'r1',
        occurrence: DateTime.utc(2026, 10, 15, 9),
      ),
    );
  });

  test('tugas dibuat dengan waktu yang sudah lewat tidak membentuk entri', () {
    // Tugas baru saja disimpan (pengingat disimpan "sekarang"), tetapi waktu
    // acuannya sudah lewat -> kemunculan itu tidak pernah dijadwalkan.
    final entries = buildFor(
      task(dueAt: now.subtract(const Duration(hours: 2))),
      reminders: [reminder(savedAt: now.toUtc())],
    );

    expect(entries, isEmpty);
  });

  test('pengingat yang waktunya diubah ke masa lalu tidak membentuk entri', () {
    // Tugas lama, tetapi pengingat baru saja disimpan ulang dengan titik acuan
    // di masa lalu.
    final entries = buildFor(
      task(
        dueAt: now.subtract(const Duration(hours: 1)),
        createdAt: DateTime.utc(2026, 1, 1),
      ),
      reminders: [reminder(savedAt: now.toUtc())],
    );

    expect(entries, isEmpty);
  });

  test('kemunculan sebelum pengingat disimpan tidak membentuk entri', () {
    // Pengingat disimpan sejam lalu, waktu acuan 3 jam lalu -> kemunculannya
    // lebih awal dari saat pengingat ada.
    final entries = buildFor(
      task(dueAt: now.subtract(const Duration(hours: 3))),
      reminders: [
        reminder(savedAt: now.subtract(const Duration(hours: 1)).toUtc()),
      ],
    );

    expect(entries, isEmpty);
  });

  test('kemunculan setelah pengingat disimpan tetap dibentuk meski tugas baru '
      'disimpan', () {
    // Pengingat disimpan dua hari lalu, waktu acuan satu hari lalu.
    final entries = buildFor(
      task(dueAt: now.subtract(const Duration(days: 1))),
      reminders: [
        reminder(savedAt: now.subtract(const Duration(days: 2)).toUtc()),
      ],
    );

    expect(entries, hasLength(1));
  });

  test('waktu simpan dipakai dari yang paling baru (createdAt vs updatedAt)',
      () {
    final reminderWithNewerUpdated = TaskReminder(
      id: 'r1',
      taskId: 't1',
      offsetMinutes: 0,
      createdAt: DateTime.utc(2026, 1, 1),
      updatedAt: now.toUtc(),
    );

    final entries = buildFor(
      task(dueAt: now.subtract(const Duration(hours: 1))),
      reminders: [reminderWithNewerUpdated],
    );

    expect(entries, isEmpty);
  });

  test('tugas yang sudah selesai tetap mencatat kemunculan sebelum selesai', () {
    final completedAt = now.subtract(const Duration(hours: 1));
    final entries = buildFor(
      task(
        status: TaskStatus.done,
        dueAt: now.subtract(const Duration(hours: 3)),
        completedAt: completedAt,
      ),
      reminders: [
        reminder(savedAt: now.subtract(const Duration(days: 2)).toUtc()),
      ],
    );

    expect(entries, hasLength(1));
  });

  test('tugas yang sudah selesai tidak mencatat kemunculan setelah selesai',
      () {
    final completedAt = now.subtract(const Duration(hours: 3));
    final entries = buildFor(
      task(
        status: TaskStatus.done,
        dueAt: now.subtract(const Duration(hours: 1)),
        completedAt: completedAt,
      ),
      reminders: [
        reminder(savedAt: now.subtract(const Duration(days: 2)).toUtc()),
      ],
    );

    expect(entries, isEmpty);
  });

  test('tanpa pengingat tidak membentuk entri', () {
    final entries = buildFor(
      task(dueAt: now.subtract(const Duration(hours: 1))),
      reminders: const [],
    );

    expect(entries, isEmpty);
  });

  test('tipe item dipetakan ke tipe notifikasi tersimpan', () {
    expect(
      notificationTypeForTaskType(TaskType.reminder),
      NotificationType.reminder,
    );
    expect(
      notificationTypeForTaskType(TaskType.event),
      NotificationType.event,
    );
    expect(
      notificationTypeForTaskType(TaskType.task),
      NotificationType.deadline,
    );
    expect(
      notificationTypeForTaskType(TaskType.milestone),
      NotificationType.deadline,
    );
  });

  test('build menggabungkan entri seluruh tugas', () {
    final entries = NotificationHistoryBuilder.build(
      tasks: [
        task(id: 'a', dueAt: now.subtract(const Duration(hours: 1))),
        task(id: 'b', dueAt: now.subtract(const Duration(hours: 2))),
      ],
      remindersByTask: {
        'a': [reminder(id: 'ra', savedAt: DateTime.utc(2026, 1, 1))],
        'b': [reminder(id: 'rb', savedAt: DateTime.utc(2026, 1, 1))],
      },
      recurrenceByTask: const {},
      now: now,
      lookback: const Duration(days: 7),
    );

    expect(entries, hasLength(2));
  });
}
