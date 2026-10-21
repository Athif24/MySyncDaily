import 'package:flutter/foundation.dart';
import 'package:get_it/get_it.dart';
import 'package:sync_daily/core/database/app_database.dart';
import 'package:sync_daily/core/state/calendar_selection.dart';
import 'package:sync_daily/features/auth/data/repositories/user_profile_repository_impl.dart';
import 'package:sync_daily/features/auth/domain/repositories/user_profile_repository.dart';
import 'package:sync_daily/features/debug/data/debug_data_seeder.dart';
import 'package:sync_daily/features/notes/data/repositories/note_repository_impl.dart';
import 'package:sync_daily/features/notes/domain/repositories/note_repository.dart';
import 'package:sync_daily/features/notifications/data/local_reminder_scheduler.dart';
import 'package:sync_daily/features/notifications/data/reminder_permissions_impl.dart';
import 'package:sync_daily/features/notifications/data/reminder_syncing_task_repository.dart';
import 'package:sync_daily/features/notifications/data/repositories/notification_repository_impl.dart';
import 'package:sync_daily/features/notifications/domain/app_messenger.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_reconciler.dart';
import 'package:sync_daily/features/notifications/domain/reminder_notification.dart';
import 'package:sync_daily/features/notifications/domain/reminder_permissions.dart';
import 'package:sync_daily/features/notifications/domain/reminder_synchronizer.dart';
import 'package:sync_daily/features/notifications/domain/repositories/notification_repository.dart';
import 'package:sync_daily/features/notifications/domain/task_detail_opener.dart';
import 'package:sync_daily/features/notifications/presentation/go_router_task_detail_opener.dart';
import 'package:sync_daily/features/notifications/presentation/reminder_launch_consumer.dart';
import 'package:sync_daily/features/notifications/presentation/reminder_response_handler.dart';
import 'package:sync_daily/features/notifications/presentation/scaffold_messenger_app_messenger.dart';
import 'package:sync_daily/features/projects/data/repositories/project_repository_impl.dart';
import 'package:sync_daily/features/projects/domain/repositories/project_repository.dart';
import 'package:sync_daily/features/tasks/data/repositories/task_repository_impl.dart';
import 'package:sync_daily/features/tasks/domain/repositories/task_repository.dart';

final getIt = GetIt.instance;

/// Daftarkan dependency di sini secara manual (mis. repository, bloc/cubit,
/// service) saat fiturnya dikerjakan.
///
/// [database] bisa diisi saat pengujian (mis. database in-memory). Bila null,
/// database utama perangkat yang dipakai.
///
/// [reminderScheduler] dan [reminderPermissions] bisa diisi tiruan saat
/// pengujian agar plugin notifikasi tidak dipanggil; [now] menginjeksi jam.
Future<void> configureDependencies({
  AppDatabase? database,
  ReminderScheduler? reminderScheduler,
  ReminderPermissions? reminderPermissions,
  DateTime Function()? now,
}) async {
  final db = database ?? AppDatabase();
  getIt.registerSingleton<AppDatabase>(db);

  getIt.registerSingleton<ReminderScheduler>(
    reminderScheduler ?? LocalReminderScheduler(),
  );
  getIt.registerLazySingleton<ReminderPermissions>(
    () => reminderPermissions ?? ReminderPermissionsImpl(),
  );

  // Repository dasar dipakai penyinkron (baca saja) agar tidak terjadi
  // rekursi: decorator hanya dipakai oleh UI, bukan oleh penyinkron.
  final taskRepositoryBase = TaskRepositoryImpl(db.tasksDao, db.projectsDao);

  getIt.registerLazySingleton<ReminderSynchronizer>(
    () => ReminderSynchronizer(
      taskRepository: taskRepositoryBase,
      scheduler: getIt<ReminderScheduler>(),
      now: now,
    ),
  );

  getIt.registerLazySingleton<TaskRepository>(
    () => ReminderSyncingTaskRepository(
      delegate: taskRepositoryBase,
      synchronizer: getIt<ReminderSynchronizer>(),
    ),
  );
  getIt.registerLazySingleton<ProjectRepository>(
    () => ProjectRepositoryImpl(db.projectsDao),
  );
  getIt.registerLazySingleton<NoteRepository>(
    () => NoteRepositoryImpl(db.notesDao),
  );
  getIt.registerLazySingleton<NotificationRepository>(
    () => NotificationRepositoryImpl(db.notificationsDao),
  );
  getIt.registerLazySingleton<UserProfileRepository>(
    UserProfileRepositoryImpl.new,
  );

  // Menyusun riwayat notifikasi dari pengingat yang sudah berbunyi. Membaca
  // lewat repository dasar (bukan decorator) agar tidak memicu sinkronisasi.
  getIt.registerLazySingleton<NotificationHistoryReconciler>(
    () => NotificationHistoryReconciler(
      taskRepository: taskRepositoryBase,
      notificationRepository: getIt<NotificationRepository>(),
      now: now,
    ),
  );

  getIt.registerLazySingleton<ReminderResponseHandler>(
    () => ReminderResponseHandler(
      synchronizer: getIt<ReminderSynchronizer>(),
      taskRepository: getIt<TaskRepository>(),
      opener: getIt<TaskDetailOpener>(),
      messenger: getIt<AppMessenger>(),
      notificationRepository: getIt<NotificationRepository>(),
    ),
  );

  getIt.registerLazySingleton<TaskDetailOpener>(GoRouterTaskDetailOpener.new);
  getIt.registerLazySingleton<AppMessenger>(
    ScaffoldMessengerAppMessenger.new,
  );

  // Membaca notifikasi pembuka aplikasi satu kali saja (lihat kelasnya).
  getIt.registerLazySingleton<ReminderLaunchConsumer>(
    () => ReminderLaunchConsumer(
      scheduler: getIt<ReminderScheduler>(),
      handler: getIt<ReminderResponseHandler>(),
    ),
  );

  // Keadaan sesi layar (bukan data): tanggal terpilih di Kalender untuk panel
  // "Buat Baru". Lihat [CalendarSelection].
  getIt.registerLazySingleton<CalendarSelection>(CalendarSelection.new);

  if (kDebugMode) {
    getIt.registerLazySingleton<DebugDataSeeder>(
      () => DebugDataSeeder(
        database: db,
        taskRepository: getIt<TaskRepository>(),
        projectRepository: getIt<ProjectRepository>(),
        notificationRepository: getIt<NotificationRepository>(),
      ),
    );

    final version = await db.sqliteVersion();
    debugPrint('[SyncDaily] SQLite $version siap di perangkat.');
  }
}
