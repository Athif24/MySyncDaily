import 'package:flutter_test/flutter_test.dart';
import 'package:sync_daily/features/notifications/domain/reminder_schedule_planner.dart';
import 'package:sync_daily/features/tasks/domain/entities/task.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_recurrence.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_reminder.dart';

/// Semua waktu pada tes ini adalah waktu lokal (atau komponen kalender), jadi
/// hasilnya tidak bergantung pada zona waktu mesin pengujian.
void main() {
  final now = DateTime(2026, 10, 15, 12, 0);

  Task task({
    String id = 't1',
    TaskType type = TaskType.task,
    TaskStatus status = TaskStatus.todo,
    DateTime? startAt,
    DateTime? dueAt,
    bool isAllDay = false,
    DateTime? deletedAt,
  }) {
    return Task(
      id: id,
      title: 'Contoh',
      type: type,
      status: status,
      startAt: startAt,
      dueAt: dueAt,
      isAllDay: isAllDay,
      deletedAt: deletedAt,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  TaskReminder reminder(String id, int offsetMinutes) {
    return TaskReminder(
      id: id,
      taskId: 't1',
      offsetMinutes: offsetMinutes,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  TaskRecurrence daily() => TaskRecurrence(
        taskId: 't1',
        frequency: RecurrenceFrequency.daily,
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  group('ReminderSchedulePlanner', () {
    test('item berjam memakai startAt dikurangi offset', () {
      final planned = ReminderSchedulePlanner.plan(
        task: task(startAt: DateTime(2026, 10, 16, 9, 0)),
        reminders: [reminder('r1', 10)],
        now: now,
      );

      expect(planned, hasLength(1));
      expect(planned.single.fireAt, DateTime(2026, 10, 16, 8, 50));
      expect(planned.single.offsetMinutes, 10);
      expect(planned.single.taskId, 't1');
      expect(planned.single.reminderId, 'r1');
    });

    test('startAt dipakai lebih dulu daripada dueAt', () {
      final planned = ReminderSchedulePlanner.plan(
        task: task(
          startAt: DateTime(2026, 10, 16, 9, 0),
          dueAt: DateTime(2026, 10, 16, 17, 0),
        ),
        reminders: [reminder('r1', 0)],
        now: now,
      );

      expect(planned.single.fireAt, DateTime(2026, 10, 16, 9, 0));
    });

    test('item seharian berbunyi 08.00 lokal lalu dikurangi offset', () {
      final planned = ReminderSchedulePlanner.plan(
        // Seharian disimpan sebagai UTC tengah malam.
        task: task(dueAt: DateTime.utc(2026, 10, 16), isAllDay: true),
        reminders: [reminder('r1', 0), reminder('r2', 1440)],
        // Dini hari, agar pengingat 1 hari sebelumnya (08.00) belum lewat.
        now: DateTime(2026, 10, 15, 7, 0),
      );

      expect(planned, hasLength(2));
      // Offset 1 hari jatuh lebih dulu.
      expect(planned.first.fireAt, DateTime(2026, 10, 15, 8, 0));
      expect(planned.last.fireAt, DateTime(2026, 10, 16, 8, 0));
    });

    test('kemunculan yang waktunya sudah lewat tidak dijadwalkan', () {
      final planned = ReminderSchedulePlanner.plan(
        // 09.00 dikurangi 60 menit = 08.00, sudah lewat dari now 12.00.
        task: task(startAt: DateTime(2026, 10, 15, 9, 0)),
        reminders: [reminder('r1', 60)],
        now: now,
      );

      expect(planned, isEmpty);
    });

    test('waktu yang sama dengan now tetap dijadwalkan', () {
      final planned = ReminderSchedulePlanner.plan(
        task: task(startAt: DateTime(2026, 10, 15, 12, 0)),
        reminders: [reminder('r1', 0)],
        now: now,
      );

      expect(planned.single.fireAt, now);
    });

    test('hanya kemunculan dalam jendela yang dijadwalkan', () {
      final planned = ReminderSchedulePlanner.plan(
        task: task(startAt: DateTime(2026, 10, 16, 9, 0)),
        reminders: [reminder('r1', 10)],
        recurrence: daily(),
        now: now,
        window: const Duration(days: 2),
      );

      expect(planned, isNotEmpty);
      for (final item in planned) {
        expect(item.fireAt.isBefore(now), isFalse);
        expect(item.fireAt.isAfter(now.add(const Duration(days: 2))), isFalse);
      }
    });

    test('pengulangan harian menghasilkan satu jadwal per kemunculan', () {
      final planned = ReminderSchedulePlanner.plan(
        task: task(startAt: DateTime(2026, 10, 16, 9, 0)),
        reminders: [reminder('r1', 10)],
        recurrence: daily(),
        now: now,
        window: const Duration(days: 2),
      );

      // 16, 17, dan 18 Oktober (batas jendela 17 Okt 12.00 + slack offset).
      final days = planned.map((item) => item.fireAt.day).toSet();
      expect(days.containsAll({16, 17}), isTrue);
      expect(planned.map((item) => item.fireAt).toList(),
          orderedEquals(planned.map((item) => item.fireAt).toList()..sort()));
    });

    test('dibatasi jumlah alarm per tugas', () {
      final planned = ReminderSchedulePlanner.plan(
        task: task(startAt: DateTime(2026, 10, 16, 9, 0)),
        reminders: [reminder('r1', 10), reminder('r2', 60)],
        recurrence: daily(),
        now: now,
        maxPerTask: 3,
      );

      expect(planned, hasLength(3));
    });

    test('tugas selesai tidak menghasilkan jadwal', () {
      final planned = ReminderSchedulePlanner.plan(
        task: task(
          startAt: DateTime(2026, 10, 16, 9, 0),
          status: TaskStatus.done,
        ),
        reminders: [reminder('r1', 10)],
        now: now,
      );

      expect(planned, isEmpty);
    });

    test('tugas terhapus tidak menghasilkan jadwal', () {
      final planned = ReminderSchedulePlanner.plan(
        task: task(
          startAt: DateTime(2026, 10, 16, 9, 0),
          deletedAt: DateTime(2026, 10, 15),
        ),
        reminders: [reminder('r1', 10)],
        now: now,
      );

      expect(planned, isEmpty);
    });

    test('tanpa pengingat atau tanpa tanggal acuan tidak ada jadwal', () {
      expect(
        ReminderSchedulePlanner.plan(
          task: task(startAt: DateTime(2026, 10, 16, 9, 0)),
          reminders: const [],
          now: now,
        ),
        isEmpty,
      );
      expect(
        ReminderSchedulePlanner.plan(
          task: task(),
          reminders: [reminder('r1', 10)],
          now: now,
        ),
        isEmpty,
      );
    });

    test('ID jadwal deterministik dan unik antar kemunculan', () {
      final first = ReminderSchedulePlanner.plan(
        task: task(startAt: DateTime(2026, 10, 16, 9, 0)),
        reminders: [reminder('r1', 10)],
        recurrence: daily(),
        now: now,
        window: const Duration(days: 3),
      );
      final second = ReminderSchedulePlanner.plan(
        task: task(startAt: DateTime(2026, 10, 16, 9, 0)),
        reminders: [reminder('r1', 10)],
        recurrence: daily(),
        now: now,
        window: const Duration(days: 3),
      );

      expect(
        first.map((item) => item.id).toList(),
        orderedEquals(second.map((item) => item.id).toList()),
      );
      expect(first.map((item) => item.id).toSet(), hasLength(first.length));
    });
  });

  group('ReminderSchedulePlanner jam seharian dari pengaturan', () {
    // Item seharian memakai komponen tanggal occurrence, jadi hasil jamnya
    // tidak bergantung zona waktu mesin pengujian.
    Task allDayTask() =>
        task(dueAt: DateTime.utc(2026, 10, 16), isAllDay: true);

    test('jam bawaan 480 sama dengan perilaku lama (08.00)', () {
      final planned = ReminderSchedulePlanner.plan(
        task: allDayTask(),
        reminders: [reminder('r1', 0)],
        now: DateTime(2026, 10, 15, 7, 0),
        allDayHourMinutes: 480,
      );

      expect(planned, hasLength(1));
      expect(planned.single.fireAt, DateTime(2026, 10, 16, 8, 0));
    });

    test('tanpa parameter sama dengan 480', () {
      final tanpaParameter = ReminderSchedulePlanner.plan(
        task: allDayTask(),
        reminders: [reminder('r1', 0)],
        now: DateTime(2026, 10, 15, 7, 0),
      );
      final denganParameter = ReminderSchedulePlanner.plan(
        task: allDayTask(),
        reminders: [reminder('r1', 0)],
        now: DateTime(2026, 10, 15, 7, 0),
        allDayHourMinutes: 480,
      );

      expect(
        tanpaParameter.map((item) => item.fireAt).toList(),
        orderedEquals(denganParameter.map((item) => item.fireAt).toList()),
      );
    });

    test('jam 1230 (20.30) dipakai untuk item seharian', () {
      final planned = ReminderSchedulePlanner.plan(
        task: allDayTask(),
        reminders: [reminder('r1', 0)],
        now: DateTime(2026, 10, 15, 7, 0),
        allDayHourMinutes: 1230,
      );

      expect(planned, hasLength(1));
      expect(planned.single.fireAt, DateTime(2026, 10, 16, 20, 30));
    });

    test('batas bawah 0 berarti 00.00', () {
      final planned = ReminderSchedulePlanner.plan(
        task: allDayTask(),
        reminders: [reminder('r1', 0)],
        now: DateTime(2026, 10, 15, 7, 0),
        allDayHourMinutes: 0,
      );

      expect(planned, hasLength(1));
      expect(planned.single.fireAt, DateTime(2026, 10, 16, 0, 0));
    });

    test('batas atas 1439 berarti 23.59', () {
      final planned = ReminderSchedulePlanner.plan(
        task: allDayTask(),
        reminders: [reminder('r1', 0)],
        now: DateTime(2026, 10, 15, 7, 0),
        allDayHourMinutes: 1439,
      );

      expect(planned, hasLength(1));
      expect(planned.single.fireAt, DateTime(2026, 10, 16, 23, 59));
    });

    test('offset pengingat tetap dikurangi dari jam yang dipilih', () {
      final planned = ReminderSchedulePlanner.plan(
        task: allDayTask(),
        reminders: [reminder('r1', 30)],
        now: DateTime(2026, 10, 15, 7, 0),
        allDayHourMinutes: 1230,
      );

      expect(planned, hasLength(1));
      expect(planned.single.fireAt, DateTime(2026, 10, 16, 20, 0));
    });
  });
}
