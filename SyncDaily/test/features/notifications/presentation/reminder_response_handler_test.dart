import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_id.dart';
import 'package:sync_daily/features/notifications/domain/reminder_notification.dart';
import 'package:sync_daily/features/notifications/domain/reminder_response_deduplicator.dart';
import 'package:sync_daily/features/notifications/domain/reminder_synchronizer.dart';
import 'package:sync_daily/features/notifications/presentation/reminder_response_handler.dart';
import 'package:sync_daily/features/tasks/domain/entities/task.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';

import '../../../helpers/fake_reminder_presentation.dart';
import '../../../helpers/fake_reminder_scheduler.dart';
import '../../../helpers/test_repositories.dart';

void main() {
  late MockTaskRepository repository;
  late MockNotificationRepository notificationRepository;
  late FakeReminderScheduler scheduler;
  late ReminderSynchronizer synchronizer;
  late FakeTaskDetailOpener opener;
  late FakeAppMessenger messenger;
  late DateTime current;

  final occurrence = DateTime.utc(2026, 10, 16, 8);

  Task activeTask() => Task(
        id: 't1',
        title: 'Rapat tim',
        type: TaskType.task,
        status: TaskStatus.todo,
        startAt: DateTime(2026, 10, 16, 9, 0),
        createdAt: DateTime(2026),
        updatedAt: DateTime(2026),
      );

  ReminderResponseHandler buildHandler() => ReminderResponseHandler(
        synchronizer: synchronizer,
        taskRepository: repository,
        opener: opener,
        messenger: messenger,
        notificationRepository: notificationRepository,
        deduplicator: ReminderResponseDeduplicator(now: () => current),
      );

  setUpAll(() {
    registerFallbackValue(TaskStatus.todo);
  });

  setUp(() {
    current = DateTime(2026, 10, 15, 12, 0);
    repository = MockTaskRepository();
    notificationRepository = MockNotificationRepository();
    scheduler = FakeReminderScheduler();
    synchronizer = ReminderSynchronizer(
      taskRepository: repository,
      scheduler: scheduler,
      now: () => current,
    );
    opener = FakeTaskDetailOpener();
    messenger = FakeAppMessenger();
    when(() => repository.setStatus(any(), any())).thenAnswer((_) async {});
    when(() => repository.getTask('t1')).thenAnswer((_) async => activeTask());
    when(() => notificationRepository.markRead(any())).thenAnswer((_) async {});
  });

  /// Kunci entri riwayat untuk kemunculan di atas.
  String historyId() => NotificationHistoryId.forReminder(
        taskId: 't1',
        reminderId: 'r1',
        occurrence: occurrence,
      );

  group('ketukan badan notifikasi', () {
    test('ketukan yang sama dua kali hanya membuka detail satu kali', () async {
      final handler = buildHandler();
      const tap = ReminderResponse(notificationId: 10, taskId: 't1');

      await handler.handle(tap);
      await handler.handle(tap);

      expect(opener.openedTaskIds, ['t1']);
    });

    test('ketukan dari notifikasi berbeda tidak dianggap duplikat', () async {
      final handler = buildHandler();

      await handler.handle(
        const ReminderResponse(notificationId: 10, taskId: 't1'),
      );
      await handler.handle(
        const ReminderResponse(notificationId: 11, taskId: 't1'),
      );

      expect(opener.openedTaskIds, ['t1', 't1']);
    });

    test('tidak memanggil setStatus maupun tunda', () async {
      final handler = buildHandler();

      await handler.handle(
        const ReminderResponse(notificationId: 10, taskId: 't1'),
      );

      verifyNever(() => repository.setStatus(any(), any()));
      expect(scheduler.scheduled, isEmpty);
      expect(messenger.messages, isEmpty);
    });
  });

  group('aksi Selesai', () {
    test('menandai selesai tanpa membuka detail', () async {
      final handler = buildHandler();

      await handler.handle(const ReminderResponse(
        notificationId: 20,
        taskId: 't1',
        actionId: ReminderAction.done,
      ));

      verify(() => repository.setStatus('t1', TaskStatus.done)).called(1);
      expect(opener.openedTaskIds, isEmpty);
      expect(scheduler.scheduled, isEmpty);
      expect(messenger.messages, [AppStrings.notificationDoneConfirmation]);
    });

    test('respons kembar tidak menandai atau mengumbar pesan dua kali',
        () async {
      final handler = buildHandler();
      const done = ReminderResponse(
        notificationId: 20,
        taskId: 't1',
        actionId: ReminderAction.done,
      );

      await handler.handle(done);
      await handler.handle(done);

      verify(() => repository.setStatus('t1', TaskStatus.done)).called(1);
      expect(messenger.messages, hasLength(1));
    });
  });

  group('aksi Tunda', () {
    test('menjadwalkan tunda tanpa membuka detail', () async {
      final handler = buildHandler();

      await handler.handle(const ReminderResponse(
        notificationId: 30,
        taskId: 't1',
        actionId: ReminderAction.snooze,
      ));

      expect(opener.openedTaskIds, isEmpty);
      expect(scheduler.pending.where((pending) => pending.isSnooze), hasLength(1));
      expect(messenger.messages, [AppStrings.notificationSnoozedConfirmation]);
    });

    test('dipanggil dua kali menghasilkan satu jadwal tunda per tugas',
        () async {
      final handler = buildHandler();

      await handler.handle(const ReminderResponse(
        notificationId: 30,
        taskId: 't1',
        actionId: ReminderAction.snooze,
      ));
      current = current.add(const Duration(seconds: 2));
      await handler.handle(const ReminderResponse(
        notificationId: 31,
        taskId: 't1',
        actionId: ReminderAction.snooze,
      ));

      final pendingSnoozes =
          scheduler.pending.where((pending) => pending.isSnooze).toList();
      expect(pendingSnoozes, hasLength(1));
      final snoozeIds = scheduler.scheduled
          .where((notification) => notification.isSnooze)
          .map((notification) => notification.id)
          .toSet();
      expect(snoozeIds, hasLength(1), reason: 'ID tunda sama sehingga menimpa');
    });
  });

  group('menandai entri riwayat dibaca', () {
    test('ketukan badan menandai entri dibaca lalu membuka detail',
        () async {
      final handler = buildHandler();

      await handler.handle(ReminderResponse(
        notificationId: 10,
        taskId: 't1',
        reminderId: 'r1',
        occurrence: occurrence,
      ));

      verify(() => notificationRepository.markRead(historyId())).called(1);
      expect(opener.openedTaskIds, ['t1']);
    });

    test('aksi Selesai menandai entri dibaca', () async {
      final handler = buildHandler();

      await handler.handle(ReminderResponse(
        notificationId: 20,
        taskId: 't1',
        reminderId: 'r1',
        occurrence: occurrence,
        actionId: ReminderAction.done,
      ));

      verify(() => notificationRepository.markRead(historyId())).called(1);
    });

    test('notifikasi tunda (tanpa pengingat/kemunculan) tidak menandai apa pun',
        () async {
      final handler = buildHandler();

      await handler.handle(const ReminderResponse(
        notificationId: 30,
        taskId: 't1',
        isSnooze: true,
        actionId: ReminderAction.snooze,
      ));

      verifyNever(() => notificationRepository.markRead(any()));
    });
  });
}
