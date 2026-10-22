import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_reconciler.dart';
import 'package:sync_daily/features/notifications/domain/reminder_notification.dart';
import 'package:sync_daily/features/notifications/domain/reminder_notification_id.dart';
import 'package:sync_daily/features/notifications/domain/reminder_schedule_planner.dart';
import 'package:sync_daily/features/notifications/domain/reminder_synchronizer.dart';
import 'package:sync_daily/features/notifications/domain/repositories/notification_repository.dart';
import 'package:sync_daily/features/settings/domain/app_settings.dart';
import 'package:sync_daily/features/settings/domain/app_settings_repository.dart';
import 'package:sync_daily/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:sync_daily/features/tasks/domain/entities/task.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_reminder.dart';

import '../../helpers/fake_reminder_scheduler.dart';
import '../../helpers/test_repositories.dart';

/// Repository pengaturan yang nilainya bisa diubah di tengah tes.
class _MutableSettingsRepository implements AppSettingsRepository {
  _MutableSettingsRepository([AppSettings? initial])
      : _settings = initial ?? const AppSettings();

  AppSettings _settings;

  @override
  AppSettings get settings => _settings;

  set settings(AppSettings value) => _settings = value;

  @override
  Stream<AppSettings> get stream => const Stream<AppSettings>.empty();

  @override
  Future<void> init() async {}

  @override
  Future<void> update(AppSettings settings) async {
    _settings = settings;
  }

  @override
  Future<void> reset() async {
    _settings = const AppSettings();
  }
}

/// Sinkronisasi palsu untuk menguji urutan dari kubit.
class _RecordingSynchronizer extends ReminderSynchronizer {
  _RecordingSynchronizer()
      : super(
          taskRepository: MockTaskRepository(),
          scheduler: FakeReminderScheduler(),
        );

  final List<String> calls = <String>[];

  @override
  Future<void> resyncAll({bool force = false}) async {
    calls.add('resyncAll(force: $force)');
  }
}

/// Repository notifikasi in-memory dengan semantik "sisip bila belum ada".
class _InMemoryNotificationRepository implements NotificationRepository {
  final Map<String, AppNotification> entries = <String, AppNotification>{};
  int insertCalls = 0;

  @override
  Future<void> insertIfAbsent(AppNotification notification) async {
    insertCalls++;
    entries.putIfAbsent(notification.id, () => notification);
  }

  @override
  Future<void> pruneHistory({
    required DateTime olderThan,
    required DateTime keepNewerThan,
    required int maxEntries,
  }) async {}

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      super.noSuchMethod(invocation);
}

/// Perilaku jam seharian yang diatur pengguna (F9a).
///
/// Semua waktu memakai waktu lokal; item seharian memakai komponen tanggal
/// occurrence, sehingga jamnya tidak bergantung zona waktu mesin.
void main() {
  // 22 Okt 2026, 14.00 waktu lokal.
  final now = DateTime(2026, 10, 22, 14, 0);

  // 20.00 = 1200 menit, 08.00 = 480 menit, 22.00 = 1320 menit,
  // 09.00 = 540 menit.
  const jam20 = 1200;
  const jam08 = 480;
  const jam09 = 540;
  const jam22 = 1320;

  // Item seharian untuk hari ini (disimpan sebagai UTC tengah malam).
  final hariIni = DateTime.utc(2026, 10, 22);

  Task allDayTask({TaskType type = TaskType.task}) => Task(
        id: 't1',
        title: 'Rapat tim',
        type: type,
        dueAt: hariIni,
        isAllDay: true,
        createdAt: DateTime.utc(2026, 10, 1),
        updatedAt: DateTime.utc(2026, 10, 1),
      );

  TaskReminder reminder({String id = 'r1', int offsetMinutes = 0}) =>
      TaskReminder(
        id: id,
        taskId: 't1',
        offsetMinutes: offsetMinutes,
        createdAt: DateTime.utc(2026, 10, 1),
        updatedAt: DateTime.utc(2026, 10, 1),
      );

  setUpAll(() {
    registerFallbackValue(<TaskReminder>[]);
  });

  group('Perubahan jam seharian', () {
    test('item seharian hari ini tidak dijadwalkan setelah jam diubah ke '
        'waktu yang sudah lewat', () {
      final planned = ReminderSchedulePlanner.plan(
        task: allDayTask(),
        reminders: [reminder()],
        now: now,
        allDayHourMinutes: jam08,
      );

      expect(
        planned,
        isEmpty,
        reason: 'jam 08.00 hari ini sudah lewat (sekarang 14.00), jadi '
            'tidak boleh dijadwalkan dan tidak boleh bunyi seketika',
      );
    });

    test('jam 20.00 masih dijadwalkan sebelum diubah', () {
      final planned = ReminderSchedulePlanner.plan(
        task: allDayTask(),
        reminders: [reminder()],
        now: now,
        allDayHourMinutes: jam20,
      );

      expect(planned, hasLength(1));
      expect(planned.single.fireAt, DateTime(2026, 10, 22, 20, 0));
    });

    test('jadwal lama 20.00 yang belum bunyi dibatalkan setelah jam diubah',
        () async {
      final readRepository = MockTaskRepository();
      final settings = _MutableSettingsRepository(
        const AppSettings(allDayReminderHourMinutes: jam20),
      );

      when(() => readRepository.getTask('t1'))
          .thenAnswer((_) async => allDayTask());
      when(() => readRepository.getReminders('t1'))
          .thenAnswer((_) async => [reminder()]);
      when(() => readRepository.getRecurrence('t1'))
          .thenAnswer((_) async => null);
      when(() => readRepository.getAllReminders())
          .thenAnswer((_) async => [reminder()]);

      // Jadwal lama (20.00) dan satu jadwal tunda masih tertunda.
      final idLama = ReminderNotificationId.forOccurrence(
        taskId: 't1',
        reminderId: 'r1',
        occurrence: hariIni,
      );
      final scheduler = FakeReminderScheduler(
        pending: [
          PendingReminder(id: idLama, taskId: 't1'),
          const PendingReminder(id: 777, taskId: 't1', isSnooze: true),
        ],
      );

      // Jam diubah ke 08.00: lewat, jadi tidak ada jadwal yang diinginkan.
      settings.settings =
          const AppSettings(allDayReminderHourMinutes: jam08);
      final synchronizer = ReminderSynchronizer(
        taskRepository: readRepository,
        scheduler: scheduler,
        now: () => now,
        minResyncInterval: Duration.zero,
        settingsRepository: settings,
      );

      await synchronizer.syncTask('t1');

      expect(
        scheduler.cancelled,
        contains(idLama),
        reason: 'jadwal 20.00 yang belum bunyi harus dibatalkan',
      );
      expect(scheduler.scheduled, isEmpty);
      expect(
        scheduler.cancelled,
        isNot(contains(777)),
        reason: 'jadwal tunda tidak boleh ikut dibatalkan',
      );
    });

    test('jadwal lama tertimpa lewat id yang sama saat jam diubah ke waktu '
        'yang masih akan datang', () async {
      final readRepository = MockTaskRepository();
      final settings = _MutableSettingsRepository(
        const AppSettings(allDayReminderHourMinutes: jam20),
      );

      when(() => readRepository.getTask('t1'))
          .thenAnswer((_) async => allDayTask());
      when(() => readRepository.getReminders('t1'))
          .thenAnswer((_) async => [reminder()]);
      when(() => readRepository.getRecurrence('t1'))
          .thenAnswer((_) async => null);

      final idLama = ReminderNotificationId.forOccurrence(
        taskId: 't1',
        reminderId: 'r1',
        occurrence: hariIni,
      );
      final scheduler = FakeReminderScheduler(
        pending: [PendingReminder(id: idLama, taskId: 't1')],
      );

      // Jam diubah ke 22.00: masih akan datang, jadi id yang sama dipakai
      // ulang (menimpa, bukan menggandakan).
      settings.settings =
          const AppSettings(allDayReminderHourMinutes: jam22);
      final synchronizer = ReminderSynchronizer(
        taskRepository: readRepository,
        scheduler: scheduler,
        now: () => now,
        minResyncInterval: Duration.zero,
        settingsRepository: settings,
      );

      await synchronizer.syncTask('t1');

      expect(scheduler.scheduled, hasLength(1));
      expect(scheduler.scheduled.single.id, idLama);
      expect(scheduler.scheduled.single.fireAt, DateTime(2026, 10, 22, 22, 0));
      expect(
        scheduler.cancelled,
        isNot(contains(idLama)),
        reason: 'id sama berarti ditimpa, bukan dibatalkan lalu dibuat lagi',
      );
      expect(
        scheduler.pending.where((pending) => pending.id == idLama),
        hasLength(1),
        reason: 'tidak boleh ada jadwal ganda untuk kemunculan yang sama',
      );
    });

    test('simulasi putus di tengah: pengaturan tersimpan tapi sinkronisasi '
        'belum jalan, sinkronisasi berikutnya memulihkan jadwal', () async {
      final readRepository = MockTaskRepository();
      final settings = _MutableSettingsRepository(
        const AppSettings(allDayReminderHourMinutes: jam20),
      );

      when(() => readRepository.getTask('t1'))
          .thenAnswer((_) async => allDayTask());
      when(() => readRepository.getReminders('t1'))
          .thenAnswer((_) async => [reminder()]);
      when(() => readRepository.getRecurrence('t1'))
          .thenAnswer((_) async => null);
      when(() => readRepository.getAllReminders())
          .thenAnswer((_) async => [reminder()]);

      final scheduler = FakeReminderScheduler();
      final synchronizer = ReminderSynchronizer(
        taskRepository: readRepository,
        scheduler: scheduler,
        now: () => now,
        minResyncInterval: Duration.zero,
        settingsRepository: settings,
      );

      // Pengaturan tersimpan, tapi sinkronisasi belum sempat jalan.
      settings.settings =
          const AppSettings(allDayReminderHourMinutes: jam22);
      expect(scheduler.scheduled, isEmpty);

      // Sinkronisasi berikutnya memulihkan jadwal sesuai jam terbaru.
      await synchronizer.resyncAll();

      expect(scheduler.scheduled, hasLength(1));
      expect(scheduler.scheduled.single.fireAt, DateTime(2026, 10, 22, 22, 0));
    });

    test('sinkronisasi tanpa paksa membaca jam terbaru dari pengaturan',
        () async {
      final readRepository = MockTaskRepository();
      final settings = _MutableSettingsRepository(
        const AppSettings(allDayReminderHourMinutes: jam20),
      );

      when(() => readRepository.getTask('t1'))
          .thenAnswer((_) async => allDayTask());
      when(() => readRepository.getReminders('t1'))
          .thenAnswer((_) async => [reminder()]);
      when(() => readRepository.getRecurrence('t1'))
          .thenAnswer((_) async => null);
      when(() => readRepository.getAllReminders())
          .thenAnswer((_) async => [reminder()]);

      final scheduler = FakeReminderScheduler();
      final synchronizer = ReminderSynchronizer(
        taskRepository: readRepository,
        scheduler: scheduler,
        now: () => now,
        minResyncInterval: Duration.zero,
        settingsRepository: settings,
      );

      await synchronizer.resyncAll();
      expect(scheduler.scheduled.single.fireAt, DateTime(2026, 10, 22, 20, 0));

      settings.settings =
          const AppSettings(allDayReminderHourMinutes: jam22);
      await synchronizer.resyncAll();

      expect(scheduler.scheduled.last.fireAt, DateTime(2026, 10, 22, 22, 0));
    });
  });

  group('Riwayat notifikasi saat jam seharian berubah', () {
    late MockTaskRepository taskRepository;
    late _InMemoryNotificationRepository notificationRepository;

    setUp(() {
      taskRepository = MockTaskRepository();
      notificationRepository = _InMemoryNotificationRepository();
      when(() => taskRepository.getAllTasks())
          .thenAnswer((_) async => [allDayTask()]);
      when(() => taskRepository.getAllReminders())
          .thenAnswer((_) async => [reminder()]);
      when(() => taskRepository.getAllRecurrences())
          .thenAnswer((_) async => const []);
    });

    NotificationHistoryReconciler buildReconciler({
      required AppSettingsRepository settings,
    }) {
      return NotificationHistoryReconciler(
        taskRepository: taskRepository,
        notificationRepository: notificationRepository,
        now: () => now,
        lookback: const Duration(days: 7),
        retention: const Duration(days: 30),
        maxEntries: 200,
        minInterval: Duration.zero,
        settingsRepository: settings,
      );
    }

    test('entri yang sudah terbentuk tidak berubah waktu bunyinya dan tidak '
        'menggandakan', () async {
      final settings = _MutableSettingsRepository(
        const AppSettings(allDayReminderHourMinutes: jam08),
      );
      final reconciler = buildReconciler(settings: settings);

      await reconciler.reconcile();

      expect(notificationRepository.entries, hasLength(1));
      final entri = notificationRepository.entries.values.single;
      expect(entri.scheduledAt, DateTime(2026, 10, 22, 8, 0).toUtc());

      // Jam diubah ke 09.00 (masih lewat, jadi kemunculan ini tetap dihitung
      // riwayat): riwayat disusun ulang, tapi entri lama tidak ditimpa.
      settings.settings =
          const AppSettings(allDayReminderHourMinutes: jam09);
      await reconciler.reconcile(force: true);

      expect(
        notificationRepository.entries,
        hasLength(1),
        reason: 'tidak boleh ada entri ganda',
      );
      expect(
        notificationRepository.entries.values.single.scheduledAt,
        DateTime(2026, 10, 22, 8, 0).toUtc(),
        reason: 'waktu bunyi entri yang sudah terbentuk tidak boleh berubah',
      );
      expect(
        notificationRepository.insertCalls,
        2,
        reason: 'penyusunan ulang benar-benar terjadi dan tidak menimpa '
            'entri lama',
      );
    });

    test('kubit melewati throttle 5 detik: riwayat tetap disusun ulang',
        () async {
      final settings = _MutableSettingsRepository(
        const AppSettings(allDayReminderHourMinutes: jam08),
      );
      final reconciler = NotificationHistoryReconciler(
        taskRepository: taskRepository,
        notificationRepository: notificationRepository,
        now: () => now,
        lookback: const Duration(days: 7),
        retention: const Duration(days: 30),
        maxEntries: 200,
        minInterval: const Duration(seconds: 5),
        settingsRepository: settings,
      );
      final synchronizer = _RecordingSynchronizer();
      final cubit = SettingsCubit(
        repository: settings,
        reconciler: reconciler,
        synchronizer: synchronizer,
      );
      addTearDown(cubit.close);

      // Rekonsiliasi baru saja berjalan (kurang dari 5 detik lalu).
      await reconciler.reconcile();
      expect(notificationRepository.insertCalls, 1);

      // Tanpa paksa, panggilan berikutnya dilewati throttle: di sinilah
      // riwayat dengan jam LAMA bisa terlewat.
      await reconciler.reconcile();
      expect(notificationRepository.insertCalls, 1);

      // Kubit memakai paksa, jadi riwayat (dengan jam lama) tetap disusun
      // ulang sebelum jam baru disimpan.
      await cubit.updateAllDayHourMinutes(jam09);

      expect(
        notificationRepository.insertCalls,
        2,
        reason: 'riwayat dengan jam lama harus disusun sebelum jam disimpan',
      );
      expect(synchronizer.calls, ['resyncAll(force: true)']);
      expect(settings.settings.allDayReminderHourMinutes, jam09);
    });
  });
}
