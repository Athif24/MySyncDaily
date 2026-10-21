import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_reconciler.dart';
import 'package:sync_daily/features/tasks/domain/entities/task.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_recurrence.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_reminder.dart';

import '../../../helpers/test_repositories.dart';

void main() {
  late MockTaskRepository taskRepository;
  late MockNotificationRepository notificationRepository;
  late DateTime now;

  final savedAt = DateTime.utc(2026, 1, 1);

  setUpAll(() {
    registerFallbackValue(
      AppNotification(
        id: 'x',
        type: NotificationType.reminder,
        title: 'x',
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      ),
    );
    registerFallbackValue(DateTime.utc(2026));
  });

  setUp(() {
    now = DateTime.utc(2026, 10, 15, 12);
    taskRepository = MockTaskRepository();
    notificationRepository = MockNotificationRepository();
    when(() => taskRepository.getAllReminders())
        .thenAnswer((_) async => <TaskReminder>[]);
    when(() => taskRepository.getAllRecurrences())
        .thenAnswer((_) async => <TaskRecurrence>[]);
    when(() => taskRepository.getAllTasks()).thenAnswer((_) async => <Task>[]);
    when(() => notificationRepository.insertIfAbsent(any()))
        .thenAnswer((_) async {});
    when(
      () => notificationRepository.pruneHistory(
        olderThan: any(named: 'olderThan'),
        keepNewerThan: any(named: 'keepNewerThan'),
        maxEntries: any(named: 'maxEntries'),
      ),
    ).thenAnswer((_) async {});
  });

  NotificationHistoryReconciler buildReconciler({
    Duration minInterval = const Duration(seconds: 5),
  }) {
    return NotificationHistoryReconciler(
      taskRepository: taskRepository,
      notificationRepository: notificationRepository,
      now: () => now,
      lookback: const Duration(days: 7),
      retention: const Duration(days: 30),
      maxEntries: 200,
      minInterval: minInterval,
    );
  }

  Task task({String id = 't1'}) => Task(
        id: id,
        title: 'Rapat tim',
        type: TaskType.task,
        dueAt: DateTime.utc(2026, 10, 15, 9),
        createdAt: savedAt,
        updatedAt: savedAt,
      );

  TaskReminder reminder({String id = 'r1', String taskId = 't1'}) =>
      TaskReminder(
        id: id,
        taskId: taskId,
        offsetMinutes: 0,
        createdAt: savedAt,
        updatedAt: savedAt,
      );

  void registerData({List<Task>? tasks, List<TaskReminder>? reminders}) {
    when(() => taskRepository.getAllTasks())
        .thenAnswer((_) async => tasks ?? [task()]);
    when(() => taskRepository.getAllReminders())
        .thenAnswer((_) async => reminders ?? [reminder()]);
  }

  test('menyisipkan entri untuk pengingat yang sudah berbunyi', () async {
    registerData();

    await buildReconciler().reconcile();

    final captured = verify(
      () => notificationRepository.insertIfAbsent(captureAny()),
    ).captured.cast<AppNotification>();
    expect(captured, hasLength(1));
    expect(captured.single.entityId, 't1');
    expect(captured.single.isRead, isFalse);
  });

  test('memakai jendela lookback dan retensi saat memangkas riwayat', () async {
    await buildReconciler().reconcile();

    verify(
      () => notificationRepository.pruneHistory(
        olderThan: now.subtract(const Duration(days: 30)),
        keepNewerThan: now.subtract(const Duration(days: 7)),
        maxEntries: 200,
      ),
    ).called(1);
  });

  test('tidak membentuk entri bila tidak ada pengingat', () async {
    registerData(tasks: [task()], reminders: const []);

    await buildReconciler().reconcile();

    verifyNever(() => notificationRepository.insertIfAbsent(any()));
  });

  test('panggilan bersamaan menunggu proses yang sama, bukan menggandakan',
      () async {
    final reconciler = buildReconciler();

    await Future.wait([
      reconciler.reconcile(),
      reconciler.reconcile(),
      reconciler.reconcile(),
    ]);

    // Hanya satu pembacaan tugas & satu pemangkasan untuk ketiga panggilan.
    verify(() => taskRepository.getAllTasks()).called(1);
    verify(
      () => notificationRepository.pruneHistory(
        olderThan: any(named: 'olderThan'),
        keepNewerThan: any(named: 'keepNewerThan'),
        maxEntries: any(named: 'maxEntries'),
      ),
    ).called(1);
  });

  test('dibatasi frekuensinya, tetapi bisa dipaksa', () async {
    final reconciler = buildReconciler();

    await reconciler.reconcile();
    await reconciler.reconcile();
    verify(() => taskRepository.getAllTasks()).called(1);

    clearInteractions(taskRepository);
    await reconciler.reconcile(force: true);
    verify(() => taskRepository.getAllTasks()).called(1);
  });

  test('kegagalan dibiarkan tidak melemparkan ke pemanggil', () async {
    when(() => taskRepository.getAllTasks())
        .thenAnswer((_) async => throw Exception('gagal'));

    await expectLater(buildReconciler().reconcile(), completes);
    verifyNever(() => notificationRepository.pruneHistory(
          olderThan: any(named: 'olderThan'),
          keepNewerThan: any(named: 'keepNewerThan'),
          maxEntries: any(named: 'maxEntries'),
        ));
  });
}
