import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_reconciler.dart';
import 'package:sync_daily/features/notifications/domain/reminder_synchronizer.dart';
import 'package:sync_daily/features/settings/domain/app_settings.dart';
import 'package:sync_daily/features/settings/domain/app_settings_repository.dart';
import 'package:sync_daily/features/settings/presentation/cubit/settings_cubit.dart';

import '../../../../helpers/fake_reminder_scheduler.dart';
import '../../../../helpers/test_repositories.dart';

/// Merekam rekonsiliasi riwayat (tanpa menyentuh database).
class _RecordingReconciler extends NotificationHistoryReconciler {
  _RecordingReconciler(this.log)
      : super(
          taskRepository: MockTaskRepository(),
          notificationRepository: MockNotificationRepository(),
        );

  final List<String> log;

  @override
  Future<void> reconcile({bool force = false}) async {
    log.add('reconcile(force: $force)');
  }
}

/// Merekam sinkronisasi ulang jadwal (tanpa menyentuh plugin notifikasi).
class _RecordingSynchronizer extends ReminderSynchronizer {
  _RecordingSynchronizer(this.log)
      : super(
          taskRepository: MockTaskRepository(),
          scheduler: FakeReminderScheduler(),
        );

  final List<String> log;

  @override
  Future<void> resyncAll({bool force = false}) async {
    log.add('resyncAll(force: $force)');
  }
}

/// Repository pengaturan palsu yang bisa gagal saat menyimpan.
class _FakeSettingsRepository implements AppSettingsRepository {
  _FakeSettingsRepository({AppSettings? initial, this.log})
      : _settings = initial ?? const AppSettings();

  final List<String>? log;
  AppSettings _settings;
  final _controller = StreamController<AppSettings>.broadcast();

  /// Bila diisi, `update` melempar galat ini.
  Object? error;

  @override
  AppSettings get settings => _settings;

  @override
  Stream<AppSettings> get stream => _controller.stream;

  @override
  Future<void> init() async {}

  @override
  Future<void> update(AppSettings settings) async {
    log?.add('update');
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    _settings = settings;
    _controller.add(settings);
  }

  @override
  Future<void> reset() async {
    _settings = const AppSettings();
    _controller.add(_settings);
  }
}

void main() {
  late List<String> log;
  late _FakeSettingsRepository repository;
  late _RecordingReconciler reconciler;
  late _RecordingSynchronizer synchronizer;
  late SettingsCubit cubit;

  setUp(() {
    log = <String>[];
    repository = _FakeSettingsRepository(log: log);
    reconciler = _RecordingReconciler(log);
    synchronizer = _RecordingSynchronizer(log);
    cubit = SettingsCubit(
      repository: repository,
      reconciler: reconciler,
      synchronizer: synchronizer,
    );
    addTearDown(cubit.close);
  });

  group('SettingsCubit.updateAllDayHourMinutes', () {
    test('menyusun riwayat dengan jam lama, menyimpan jam baru, lalu '
        'menyinkronkan paksa', () async {
      await cubit.updateAllDayHourMinutes(600);

      expect(
        log,
        [
          'reconcile(force: true)',
          'update',
          'resyncAll(force: true)',
        ],
        reason: 'urutan wajib: riwayat lama dulu, baru simpan, baru sinkron',
      );
      expect(repository.settings.allDayReminderHourMinutes, 600);
      expect(cubit.state.settings.allDayReminderHourMinutes, 600);
    });

    test('memakai paksa agar riwayat tidak dilewati throttle 5 detik',
        () async {
      await cubit.updateAllDayHourMinutes(600);

      expect(log.first, 'reconcile(force: true)');
    });

    test('bila penyimpanan gagal, sinkronisasi tidak dijalankan dan nilai '
        'tetap', () async {
      repository.error = StateError('gagal menulis');

      // Kegagalan tidak dilempar keluar (tidak boleh jadi pengecualian tak
      // tertangani di UI); pesannya dibawa lewat state.
      await cubit.updateAllDayHourMinutes(600);

      expect(log, ['reconcile(force: true)', 'update']);
      expect(
        log.contains('resyncAll(force: true)'),
        isFalse,
        reason: 'sinkronisasi tidak boleh jalan bila penyimpanan gagal',
      );
      expect(repository.settings.allDayReminderHourMinutes, 480);
      expect(cubit.state.settings.allDayReminderHourMinutes, 480);
      expect(cubit.state.errorMessage, AppStrings.settingsSaveFailed);
    });

    test('pesan kesalahan dibersihkan setelah ditampilkan', () async {
      repository.error = StateError('gagal menulis');

      await cubit.updateAllDayHourMinutes(600);
      expect(cubit.state.errorMessage, isNotNull);

      cubit.clearError();

      expect(cubit.state.errorMessage, isNull);
      expect(cubit.state.settings.allDayReminderHourMinutes, 480);
    });

    test('nilai di luar rentang dijepit ke 0..1439', () async {
      await cubit.updateAllDayHourMinutes(1500);
      expect(repository.settings.allDayReminderHourMinutes, 1439);

      await cubit.updateAllDayHourMinutes(-30);
      expect(repository.settings.allDayReminderHourMinutes, 0);
    });

    test('jam bawaan dibaca dari repository saat kubit dibuat', () {
      final lain = SettingsCubit(
        repository: _FakeSettingsRepository(
          initial: const AppSettings(allDayReminderHourMinutes: 1230),
        ),
        reconciler: reconciler,
        synchronizer: synchronizer,
      );
      addTearDown(lain.close);

      expect(lain.state.settings.allDayReminderHourMinutes, 1230);
    });
  });
}
