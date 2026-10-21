import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sync_daily/core/database/app_database.dart';
import 'package:sync_daily/core/di/injection.dart';
import 'package:sync_daily/core/router/app_router.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/core/utils/id_date.dart';
import 'package:sync_daily/core/widgets/app_chip.dart';
import 'package:sync_daily/core/widgets/empty_state.dart';
import 'package:sync_daily/core/widgets/unread_dot.dart';
import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_reconciler.dart';
import 'package:sync_daily/features/notifications/domain/repositories/notification_repository.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/domain/repositories/task_repository.dart';
import 'package:sync_daily/main.dart';

import '../../../helpers/fake_notification_repository.dart';
import '../../../helpers/reset_app_state.dart';
import '../../../helpers/test_dependencies.dart';
import '../../../helpers/test_repositories.dart';

/// Tes widget layar Notifikasi: susunan bagian tetap (kembali, judul, "Tandai
/// dibaca", chip jenis), kelompok per hari, keadaan kosong, tombol aksi yang
/// hanya tampil pada entri belum dibaca, dan ketahanan tata letak di layar
/// pendek.
void main() {
  late AppDatabase db;
  late FakeNotificationRepository notificationRepository;
  late MockTaskRepository taskRepository;

  setUpAll(() async {
    await IdDate.ensureInitialized();
    registerFallbackValue(TaskStatus.todo);
  });

  setUp(() async {
    await resetGlobalTestState();
    db = await setUpInMemoryDependencies();
    registerMockRepositories();

    taskRepository = MockTaskRepository();
    when(() => taskRepository.getTask(any())).thenAnswer((_) async => null);
    when(() => taskRepository.setStatus(any(), any())).thenAnswer((_) async {});
    when(() => taskRepository.getAllReminders())
        .thenAnswer((_) async => const []);
    when(() => taskRepository.getAllTasks())
        .thenAnswer((_) async => const []);
    when(() => taskRepository.getAllRecurrences())
        .thenAnswer((_) async => const []);

    notificationRepository = FakeNotificationRepository();
    getIt.unregister<TaskRepository>();
    getIt.registerSingleton<TaskRepository>(taskRepository);
    getIt.unregister<NotificationRepository>();
    getIt.registerSingleton<NotificationRepository>(notificationRepository);

    // Rekonsiliasi riwayat dibaca dari repository tiruan, bukan Drift, supaya
    // tidak membuka query stream Drift di dalam `flutter_test`.
    getIt.unregister<NotificationHistoryReconciler>();
    getIt.registerSingleton<NotificationHistoryReconciler>(
      NotificationHistoryReconciler(
        taskRepository: taskRepository,
        notificationRepository: notificationRepository,
        now: DateTime.now,
      ),
    );
  });

  tearDown(() async {
    await notificationRepository.dispose();
    await getIt.reset();
    await db.close();
  });

  AppNotification entry(
    String id, {
    String title = 'Rapat tim',
    String? body = 'Waktunya sekarang',
    NotificationType type = NotificationType.reminder,
    bool isRead = false,
    String? entityType = 'task',
    String? entityId = 't1',
    DateTime? createdAt,
  }) {
    final at = createdAt ?? DateTime.now();
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      entityType: entityType,
      entityId: entityId,
      scheduledAt: at,
      isRead: isRead,
      createdAt: at,
      updatedAt: at,
    );
  }

  Future<void> pumpNotifications(
    WidgetTester tester, {
    Size physicalSize = const Size(1200, 2400),
  }) async {
    AppRouter.router.go('/notifications');

    tester.view.physicalSize = physicalSize;
    tester.view.devicePixelRatio = 3.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const SyncDailyApp());
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 15),
    );
  }

  /// Chip jenis dengan label [label].
  Finder chip(String label) => find.descendant(
        of: find.byType(AppChip),
        matching: find.text(label),
      );

  group('susunan layar', () {
    testWidgets('menampilkan kembali, judul, "Tandai dibaca", dan chip jenis',
        (tester) async {
      await pumpNotifications(tester);

      expect(find.text(AppStrings.notifications), findsOneWidget);
      expect(find.text(AppStrings.notificationMarkAllRead), findsOneWidget);
      expect(chip(AppStrings.notificationKindAll), findsOneWidget);
      expect(chip(AppStrings.notificationKindReminder), findsOneWidget);
      expect(chip(AppStrings.notificationKindDeadline), findsOneWidget);
      // Chip "Pesan" disembunyikan sampai fitur chat ada.
      expect(chip(AppStrings.screenChat), findsNothing);
    });

    testWidgets('keadaan kosong tampil terpusat', (tester) async {
      await pumpNotifications(tester);

      expect(find.text(AppStrings.notificationEmpty), findsOneWidget);
      expect(find.byType(EmptyState), findsOneWidget);
    });

    testWidgets('menuangkan entri per hari beserta waktu', (tester) async {
      final now = DateTime.now();
      notificationRepository.seed(entry('a', title: 'Pagi', createdAt: now));
      notificationRepository.seed(entry(
        'b',
        title: 'Kegiatan kemarin',
        createdAt: now.subtract(const Duration(days: 1)),
      ));

      await pumpNotifications(tester);

      expect(find.text(AppStrings.notificationGroupToday), findsOneWidget);
      expect(find.text(AppStrings.notificationGroupYesterday), findsOneWidget);
      expect(find.text('Pagi'), findsOneWidget);
      expect(find.text('Kegiatan kemarin'), findsOneWidget);
    });

    testWidgets('tidak meluber di layar pendek 320x640', (tester) async {
      notificationRepository.seed(entry('a'));
      notificationRepository.seed(entry('b'));

      await pumpNotifications(
        tester,
        physicalSize: const Size(320 * 3, 640 * 3),
      );

      expect(tester.takeException(), isNull);
      expect(find.text(AppStrings.notifications), findsOneWidget);
    });
  });

  group('filter jenis', () {
    testWidgets('Deadline menyaring entri lain', (tester) async {
      notificationRepository.seed(entry('a', title: 'Pengingat A'));
      notificationRepository.seed(entry(
        'b',
        title: 'Tenggat B',
        type: NotificationType.deadline,
      ));

      await pumpNotifications(tester);

      await tester.tap(chip(AppStrings.notificationKindDeadline));
      await tester.pumpAndSettle();

      expect(find.text('Tenggat B'), findsOneWidget);
      expect(find.text('Pengingat A'), findsNothing);
    });

    testWidgets('keadaan kosong berbeda saat filter tidak cocok',
        (tester) async {
      notificationRepository.seed(entry('a', title: 'Pengingat A'));

      await pumpNotifications(tester);

      await tester.tap(chip(AppStrings.notificationKindDeadline));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.notificationNoMatch), findsOneWidget);
      expect(find.text(AppStrings.notificationEmpty), findsNothing);
    });
  });

  group('entri belum dibaca', () {
    testWidgets('menampilkan titik belum dibaca dan tombol aksi',
        (tester) async {
      notificationRepository.seed(entry('a'));

      await pumpNotifications(tester);

      expect(find.byType(UnreadDot), findsOneWidget);
      expect(
        find.text(AppStrings.notificationActionDone),
        findsOneWidget,
      );
      expect(
        find.text(AppStrings.notificationActionSnooze),
        findsOneWidget,
      );
    });

    testWidgets('entri yang sudah dibaca tidak punya tombol aksi',
        (tester) async {
      notificationRepository.seed(entry('a', isRead: true));

      await pumpNotifications(tester);

      expect(find.byType(UnreadDot), findsNothing);
      expect(find.text(AppStrings.notificationActionDone), findsNothing);
      expect(find.text(AppStrings.notificationActionSnooze), findsNothing);
    });

    testWidgets('entri tanpa tugas tidak punya tombol aksi meski belum dibaca',
        (tester) async {
      notificationRepository.seed(entry('a', entityType: null, entityId: null));

      await pumpNotifications(tester);

      expect(find.byType(UnreadDot), findsOneWidget);
      expect(find.text(AppStrings.notificationActionDone), findsNothing);
    });

    testWidgets('menekan "Selesai": tombol hilang dan muncul konfirmasi',
        (tester) async {
      notificationRepository.seed(entry('a'));

      await pumpNotifications(tester);

      await tester.tap(find.text(AppStrings.notificationActionDone));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.notificationActionDone), findsNothing);
      expect(find.byType(UnreadDot), findsNothing);
      expect(
        find.text(AppStrings.notificationDoneConfirmation),
        findsOneWidget,
      );
      verify(() => taskRepository.setStatus('t1', TaskStatus.done)).called(1);
    });

    testWidgets('menandai semua dibaca lewat "Tandai dibaca"', (tester) async {
      notificationRepository.seed(entry('a'));
      notificationRepository.seed(entry('b'));

      await pumpNotifications(tester);
      expect(find.byType(UnreadDot), findsNWidgets(2));

      await tester.tap(find.text(AppStrings.notificationMarkAllRead));
      await tester.pumpAndSettle();

      expect(find.byType(UnreadDot), findsNothing);
      expect(notificationRepository.markAllReadCalls, 1);
    });
  });
}
