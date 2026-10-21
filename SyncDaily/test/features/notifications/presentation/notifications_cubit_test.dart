import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_reconciler.dart';
import 'package:sync_daily/features/notifications/domain/notification_kind.dart';
import 'package:sync_daily/features/notifications/domain/reminder_synchronizer.dart';
import 'package:sync_daily/features/notifications/presentation/cubit/notifications_cubit.dart';
import 'package:sync_daily/features/notifications/presentation/cubit/notifications_state.dart';
import 'package:sync_daily/features/tasks/domain/entities/task.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_recurrence.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_reminder.dart';

import '../../../helpers/fake_notification_repository.dart';
import '../../../helpers/fake_reminder_presentation.dart';
import '../../../helpers/fake_reminder_scheduler.dart';
import '../../../helpers/test_repositories.dart';

void main() {
  late MockTaskRepository taskRepository;
  late FakeNotificationRepository notificationRepository;
  late FakeReminderScheduler scheduler;
  late ReminderSynchronizer synchronizer;
  late FakeTaskDetailOpener opener;
  late FakeAppMessenger messenger;
  late DateTime now;

  setUpAll(() {
    registerFallbackValue(TaskStatus.todo);
  });

  setUp(() {
    now = DateTime.utc(2026, 10, 15, 12);
    taskRepository = MockTaskRepository();
    notificationRepository = FakeNotificationRepository();
    scheduler = FakeReminderScheduler();
    synchronizer = ReminderSynchronizer(
      taskRepository: taskRepository,
      scheduler: scheduler,
      now: () => now,
    );
    opener = FakeTaskDetailOpener();
    messenger = FakeAppMessenger();

    when(() => taskRepository.getAllReminders())
        .thenAnswer((_) async => <TaskReminder>[]);
    when(() => taskRepository.getAllRecurrences())
        .thenAnswer((_) async => <TaskRecurrence>[]);
    when(() => taskRepository.getAllTasks()).thenAnswer((_) async => <Task>[]);
    when(() => taskRepository.setStatus(any(), any())).thenAnswer((_) async {});
  });

  tearDown(() async {
    await notificationRepository.dispose();
  });

  AppNotification entry(
    String id, {
    NotificationType type = NotificationType.reminder,
    bool isRead = false,
    String? entityType = 'task',
    String? entityId = 't1',
    DateTime? createdAt,
  }) {
    final at = createdAt ?? DateTime.utc(2026, 10, 15, 9);
    return AppNotification(
      id: id,
      type: type,
      title: 'Judul $id',
      body: 'Isi $id',
      entityType: entityType,
      entityId: entityId,
      scheduledAt: at,
      isRead: isRead,
      createdAt: at,
      updatedAt: at,
    );
  }

  NotificationsCubit buildCubit() => NotificationsCubit(
        notificationRepository: notificationRepository,
        taskRepository: taskRepository,
        opener: opener,
        messenger: messenger,
        synchronizer: synchronizer,
        reconciler: NotificationHistoryReconciler(
          taskRepository: taskRepository,
          notificationRepository: notificationRepository,
          now: () => now,
        ),
        now: () => now,
      );

  Future<NotificationsCubit> startCubit() async {
    final cubit = buildCubit()..start();
    await pumpEventQueue();
    return cubit;
  }

  test('memuat entri dan mengelompokkannya per hari', () async {
    notificationRepository.seed(entry('a', createdAt: DateTime.utc(2026, 10, 15, 9)));
    notificationRepository.seed(entry(
      'b',
      type: NotificationType.deadline,
      createdAt: DateTime.utc(2026, 10, 14, 9),
    ));

    final cubit = await startCubit();
    addTearDown(cubit.close);

    expect(cubit.state.status, NotificationsStatus.loaded);
    expect(cubit.state.visibleEntries, hasLength(2));
    expect(cubit.state.groups, hasLength(2));
    expect(cubit.state.allEntries.first.id, 'a');
  });

  test('memfilter jenis: Pengingat mencakup acara, Deadline tidak', () async {
    notificationRepository.seed(entry('a', type: NotificationType.reminder));
    notificationRepository.seed(entry('b', type: NotificationType.event));
    notificationRepository.seed(entry('c', type: NotificationType.deadline));

    final cubit = await startCubit();
    addTearDown(cubit.close);

    cubit.setKind(NotificationKind.reminder);
    expect(
      cubit.state.visibleEntries.map((e) => e.id).toSet(),
      {'a', 'b'},
    );

    cubit.setKind(NotificationKind.deadline);
    expect(cubit.state.visibleEntries.map((e) => e.id).toList(), ['c']);

    cubit.setKind(null);
    expect(cubit.state.visibleEntries, hasLength(3));
    expect(cubit.state.hasFilter, isFalse);
  });

  test('tanpa entri: keadaan kosong sesuai filter', () async {
    final cubit = await startCubit();
    addTearDown(cubit.close);

    expect(cubit.state.isEmpty, isTrue);
    expect(cubit.state.hasFilter, isFalse);
    expect(cubit.state.hasUnread, isFalse);
  });

  test('hasUnread mengikuti seluruh entri, bukan hanya yang tampak', () async {
    notificationRepository.seed(entry('a', type: NotificationType.deadline));

    final cubit = await startCubit();
    addTearDown(cubit.close);

    cubit.setKind(NotificationKind.reminder);
    expect(cubit.state.visibleEntries, isEmpty);
    expect(cubit.state.hasUnread, isTrue);
  });

  test('menandai semua dibaca', () async {
    notificationRepository.seed(entry('a'));

    final cubit = await startCubit();
    addTearDown(cubit.close);

    await cubit.markAllRead();
    await pumpEventQueue();

    expect(notificationRepository.markAllReadCalls, 1);
    expect(cubit.state.hasUnread, isFalse);
  });

  group('ketukan entri', () {
    test('menandai dibaca dan membuka detail bila tugas ada', () async {
      notificationRepository.seed(entry('a'));
      when(() => taskRepository.getTask('t1')).thenAnswer(
        (_) async => Task(
          id: 't1',
          title: 'Rapat',
          type: TaskType.task,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final cubit = await startCubit();
      addTearDown(cubit.close);

      await cubit.openEntry(cubit.state.visibleEntries.single);

      expect(opener.openedTaskIds, ['t1']);
      expect(notificationRepository.markedRead, ['a']);
      expect(messenger.messages, isEmpty);
    });

    test('tugas hilang: tetap ditandai dibaca, beri tahu tanpa membuka layar',
        () async {
      notificationRepository.seed(entry('a'));
      when(() => taskRepository.getTask('t1')).thenAnswer((_) async => null);

      final cubit = await startCubit();
      addTearDown(cubit.close);

      await cubit.openEntry(cubit.state.visibleEntries.single);

      expect(opener.openedTaskIds, isEmpty);
      expect(notificationRepository.markedRead, ['a']);
      expect(messenger.messages, [AppStrings.taskNotFound]);
    });

    test('entri tanpa tugas hanya ditandai dibaca', () async {
      notificationRepository.seed(
        entry('a', entityType: null, entityId: null),
      );

      final cubit = await startCubit();
      addTearDown(cubit.close);

      await cubit.openEntry(cubit.state.visibleEntries.single);

      expect(opener.openedTaskIds, isEmpty);
      expect(notificationRepository.markedRead, ['a']);
    });
  });

  test('aksi Selesai: menandai selesai, dibaca, dan memberi konfirmasi',
      () async {
    notificationRepository.seed(entry('a'));

    final cubit = await startCubit();
    addTearDown(cubit.close);

    await cubit.markDone(cubit.state.visibleEntries.single);

    verify(() => taskRepository.setStatus('t1', TaskStatus.done)).called(1);
    expect(notificationRepository.markedRead, ['a']);
    expect(messenger.messages, [AppStrings.notificationDoneConfirmation]);
  });

  test('aksi Tunda: menjadwalkan tunda, dibaca, dan memberi konfirmasi',
      () async {
    notificationRepository.seed(entry('a'));
    when(() => taskRepository.getTask('t1')).thenAnswer(
      (_) async => Task(
        id: 't1',
        title: 'Rapat',
        type: TaskType.task,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final cubit = await startCubit();
    addTearDown(cubit.close);

    await cubit.snooze(cubit.state.visibleEntries.single);

    expect(scheduler.scheduled.where((n) => n.isSnooze), hasLength(1));
    expect(notificationRepository.markedRead, ['a']);
    expect(messenger.messages, [AppStrings.notificationSnoozedConfirmation]);
  });

  test('aksi Tunda untuk tugas yang sudah selesai tidak menjadwalkan apa pun',
      () async {
    notificationRepository.seed(entry('a'));
    when(() => taskRepository.getTask('t1')).thenAnswer(
      (_) async => Task(
        id: 't1',
        title: 'Rapat',
        type: TaskType.task,
        status: TaskStatus.done,
        completedAt: now,
        createdAt: now,
        updatedAt: now,
      ),
    );

    final cubit = await startCubit();
    addTearDown(cubit.close);

    await cubit.snooze(cubit.state.visibleEntries.single);

    expect(scheduler.scheduled, isEmpty);
    expect(notificationRepository.markedRead, ['a']);
  });
}
