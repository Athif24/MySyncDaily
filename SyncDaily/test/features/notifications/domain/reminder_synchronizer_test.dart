import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sync_daily/features/notifications/data/reminder_syncing_task_repository.dart';
import 'package:sync_daily/features/notifications/domain/reminder_notification.dart';
import 'package:sync_daily/features/notifications/domain/reminder_schedule_planner.dart';
import 'package:sync_daily/features/notifications/domain/reminder_synchronizer.dart';
import 'package:sync_daily/features/tasks/domain/entities/task.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_reminder.dart';

import '../../../helpers/fake_reminder_scheduler.dart';
import '../../../helpers/test_repositories.dart';

void main() {
  late MockTaskRepository readRepository;
  late FakeReminderScheduler scheduler;
  final now = DateTime(2026, 10, 15, 12, 0);

  final reminder = TaskReminder(
    id: 'r1',
    taskId: 't1',
    offsetMinutes: 10,
    createdAt: DateTime(2026),
    updatedAt: DateTime(2026),
  );

  Task timedTask({
    TaskStatus status = TaskStatus.todo,
    DateTime? deletedAt,
  }) {
    return Task(
      id: 't1',
      title: 'Rapat tim',
      type: TaskType.task,
      status: status,
      startAt: DateTime(2026, 10, 16, 9, 0),
      deletedAt: deletedAt,
      createdAt: DateTime(2026),
      updatedAt: DateTime(2026),
    );
  }

  ReminderSynchronizer buildSynchronizer({
    Duration minResyncInterval = Duration.zero,
  }) {
    return ReminderSynchronizer(
      taskRepository: readRepository,
      scheduler: scheduler,
      now: () => now,
      minResyncInterval: minResyncInterval,
    );
  }

  void stubActiveTask({
    TaskStatus status = TaskStatus.todo,
    DateTime? deletedAt,
  }) {
    final task = timedTask(status: status, deletedAt: deletedAt);
    when(() => readRepository.getTask('t1')).thenAnswer((_) async => task);
    when(() => readRepository.getReminders('t1'))
        .thenAnswer((_) async => [reminder]);
    when(() => readRepository.getRecurrence('t1')).thenAnswer((_) async => null);
  }

  setUpAll(() {
    registerFallbackValue(<TaskReminder>[]);
  });

  setUp(() {
    readRepository = MockTaskRepository();
    scheduler = FakeReminderScheduler();
  });

  group('ReminderSynchronizer.syncTask', () {
    test('memasang jadwal yang diinginkan', () async {
      stubActiveTask();

      await buildSynchronizer().syncTask('t1');

      expect(scheduler.scheduled, hasLength(1));
      expect(scheduler.scheduled.single.taskId, 't1');
      expect(scheduler.scheduled.single.isSnooze, isFalse);
    });

    test('jadwal yang SUDAH tertunda tetap dipasang ulang', () async {
      stubActiveTask();
      final expectedId = ReminderSchedulePlanner.plan(
        task: timedTask(),
        reminders: [reminder],
        now: now,
      ).single.id;

      // Cache plugin menganggap alarm ini masih tertunda, walau alarm di sistem
      // bisa saja sudah hilang (mis. setelah "Hentikan paksa").
      scheduler = FakeReminderScheduler(
        pending: [PendingReminder(id: expectedId, taskId: 't1')],
      );

      await buildSynchronizer().syncTask('t1');

      expect(
        scheduler.scheduled.map((notification) => notification.id),
        contains(expectedId),
        reason: 'sinkronisasi harus tetap memanggil zonedSchedule',
      );
      expect(scheduler.cancelled, isEmpty);
    });

    test('pemasangan ulang idempoten (tidak menggandakan)', () async {
      stubActiveTask();
      final synchronizer = buildSynchronizer();

      await synchronizer.syncTask('t1');
      await synchronizer.syncTask('t1');

      final pendingIds = scheduler.pending.map((pending) => pending.id).toList();
      expect(pendingIds, hasLength(1));
      expect(pendingIds.toSet(), hasLength(1));
      expect(
        scheduler.scheduled
            .where((notification) => notification.id == pendingIds.single)
            .length,
        2,
        reason: 'tiap sinkronisasi memasang ulang jadwal yang sama',
      );
    });

    test('notifikasi tertunda yang tidak lagi diinginkan dibatalkan', () async {
      stubActiveTask();
      scheduler = FakeReminderScheduler(
        pending: [const PendingReminder(id: 4242, taskId: 't1')],
      );

      await buildSynchronizer().syncTask('t1');

      expect(scheduler.cancelled, contains(4242));
    });

    test('notifikasi tunda tetap dibiarkan selama tugas aktif', () async {
      stubActiveTask();
      scheduler = FakeReminderScheduler(
        pending: [const PendingReminder(id: 777, taskId: 't1', isSnooze: true)],
      );

      await buildSynchronizer().syncTask('t1');

      expect(scheduler.cancelled, isNot(contains(777)));
    });

    test('tugas selesai membatalkan semua notifikasi termasuk tunda', () async {
      stubActiveTask(status: TaskStatus.done);
      scheduler = FakeReminderScheduler(pending: [
        const PendingReminder(id: 100, taskId: 't1'),
        const PendingReminder(id: 200, taskId: 't1', isSnooze: true),
      ]);

      await buildSynchronizer().syncTask('t1');

      expect(scheduler.scheduled, isEmpty);
      expect(scheduler.cancelled, containsAll(<int>[100, 200]));
    });

    test('tugas terhapus membatalkan notifikasi', () async {
      stubActiveTask(deletedAt: DateTime(2026, 10, 15));
      scheduler = FakeReminderScheduler(
        pending: [const PendingReminder(id: 300, taskId: 't1')],
      );

      await buildSynchronizer().syncTask('t1');

      expect(scheduler.cancelled, contains(300));
    });

    test('tugas tidak ditemukan membatalkan notifikasi', () async {
      when(() => readRepository.getTask('t1')).thenAnswer((_) async => null);
      scheduler = FakeReminderScheduler(
        pending: [const PendingReminder(id: 500, taskId: 't1')],
      );

      await buildSynchronizer().syncTask('t1');

      expect(scheduler.cancelled, contains(500));
    });

    test('tidak menyentuh notifikasi milik tugas lain', () async {
      stubActiveTask();
      scheduler = FakeReminderScheduler(
        pending: [const PendingReminder(id: 900, taskId: 'lain')],
      );

      await buildSynchronizer().syncTask('t1');

      expect(scheduler.cancelled, isEmpty);
      expect(scheduler.pending.map((pending) => pending.id), contains(900));
    });
  });

  group('ReminderSynchronizer.resyncAll', () {
    test('memproses tugas yang punya pengingat', () async {
      stubActiveTask();
      when(() => readRepository.getAllReminders())
          .thenAnswer((_) async => [reminder]);

      await buildSynchronizer().resyncAll();

      expect(scheduler.scheduled, isNotEmpty);
    });

    test('dibatasi frekuensinya saat dipanggil berulang', () async {
      stubActiveTask();
      when(() => readRepository.getAllReminders())
          .thenAnswer((_) async => [reminder]);
      final synchronizer = buildSynchronizer(
        minResyncInterval: const Duration(minutes: 1),
      );

      await synchronizer.resyncAll();
      final afterFirst = scheduler.scheduled.length;
      await synchronizer.resyncAll();

      expect(scheduler.scheduled.length, afterFirst);
    });

    test('tugas tanpa pengingat tidak diproses', () async {
      when(() => readRepository.getAllReminders())
          .thenAnswer((_) async => const []);

      await buildSynchronizer().resyncAll();

      expect(scheduler.scheduled, isEmpty);
      verifyNever(() => readRepository.getTask(any()));
    });
  });

  group('ReminderSynchronizer.snooze', () {
    test('menjadwalkan tunda tepat sekarang + 10 menit', () async {
      stubActiveTask();

      await buildSynchronizer().snooze('t1');

      final snooze = scheduler.scheduled.single;
      expect(snooze.isSnooze, isTrue);
      expect(snooze.taskId, 't1');
      expect(snooze.fireAt, now.add(const Duration(minutes: 10)));
    });

    test('memanggil tunda dua kali menghasilkan satu jadwal tunda', () async {
      stubActiveTask();
      var clock = now;
      final synchronizer = ReminderSynchronizer(
        taskRepository: readRepository,
        scheduler: scheduler,
        now: () => clock,
        minResyncInterval: Duration.zero,
      );

      await synchronizer.snooze('t1');
      clock = clock.add(const Duration(seconds: 2));
      await synchronizer.snooze('t1');

      expect(
        scheduler.pending.where((pending) => pending.isSnooze),
        hasLength(1),
      );
      expect(
        scheduler.scheduled
            .where((notification) => notification.isSnooze)
            .map((notification) => notification.id)
            .toSet(),
        hasLength(1),
        reason: 'ID tunda hanya bergantung pada tugas, bukan waktu',
      );
    });

    test('sinkronisasi setelah tunda tidak membatalkan atau menggandakannya',
        () async {
      stubActiveTask();
      final synchronizer = buildSynchronizer();

      await synchronizer.snooze('t1');
      await synchronizer.syncTask('t1');

      expect(
        scheduler.pending.where((pending) => pending.isSnooze),
        hasLength(1),
      );
      expect(scheduler.cancelled, isEmpty);
    });

    test('tugas selesai tidak dijadwalkan tunda', () async {
      stubActiveTask(status: TaskStatus.done);

      await buildSynchronizer().snooze('t1');

      expect(scheduler.scheduled, isEmpty);
    });
  });

  group('ReminderSyncingTaskRepository', () {
    test('menyelaraskan pengingat setelah replaceReminders', () async {
      stubActiveTask();
      final delegate = MockTaskRepository();
      when(() => delegate.replaceReminders('t1', any()))
          .thenAnswer((_) async {});

      final repository = ReminderSyncingTaskRepository(
        delegate: delegate,
        synchronizer: buildSynchronizer(),
      );

      await repository.replaceReminders('t1', [reminder]);

      expect(scheduler.scheduled, isNotEmpty);
      verify(() => delegate.replaceReminders('t1', any())).called(1);
    });

    test('kegagalan penjadwalan tidak menggagalkan penyimpanan', () async {
      // Baca tugas melempar: sinkronisasi gagal, tetapi penyimpanan tetap
      // dianggap berhasil.
      when(() => readRepository.getTask(any()))
          .thenThrow(StateError('gagal membaca'));
      final delegate = MockTaskRepository();
      when(() => delegate.replaceReminders('t1', any()))
          .thenAnswer((_) async {});

      final repository = ReminderSyncingTaskRepository(
        delegate: delegate,
        synchronizer: buildSynchronizer(),
      );

      await expectLater(
        repository.replaceReminders('t1', [reminder]),
        completes,
      );
    });
  });
}
