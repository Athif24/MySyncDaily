import 'package:flutter_test/flutter_test.dart';
import 'package:sync_daily/core/di/injection.dart';
import 'package:sync_daily/features/settings/domain/app_settings.dart';
import 'package:sync_daily/features/settings/domain/app_settings_repository.dart';

import '../../helpers/reset_app_state.dart';

/// Repository pengaturan palsu untuk menguji reset state global.
class _FakeSettingsRepository implements AppSettingsRepository {
  _FakeSettingsRepository([AppSettings? initial])
      : _settings = initial ?? const AppSettings();

  AppSettings _settings;

  @override
  AppSettings get settings => _settings;

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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('resetGlobalTestState mengembalikan repository pengaturan ke bawaan',
      () async {
    await resetGlobalTestState();

    // Daftarkan repository pengaturan dengan nilai bukan-bawaan, seperti
    // keadaan yang ditinggalkan tes sebelumnya.
    if (getIt.isRegistered<AppSettingsRepository>()) {
      await getIt.unregister<AppSettingsRepository>();
    }
    final repository = _FakeSettingsRepository(
      const AppSettings(allDayReminderHourMinutes: 999),
    );
    getIt.registerSingleton<AppSettingsRepository>(repository);
    expect(repository.settings.allDayReminderHourMinutes, 999);

    await resetGlobalTestState();

    expect(
      repository.settings.allDayReminderHourMinutes,
      480,
      reason: 'helper reset harus mengembalikan keadaan pengaturan ke bawaan '
          'supaya tidak bocor ke tes berikutnya',
    );
    expect(repository.settings, const AppSettings());
  });

  test('tanpa helper reset, keadaan pengaturan dari tes sebelumnya tetap ada',
      () async {
    await resetGlobalTestState();
    if (getIt.isRegistered<AppSettingsRepository>()) {
      await getIt.unregister<AppSettingsRepository>();
    }
    final repository = _FakeSettingsRepository(
      const AppSettings(allDayReminderHourMinutes: 999),
    );
    getIt.registerSingleton<AppSettingsRepository>(repository);

    // Perilaku lama: get_it dibuang, tetapi keadaan repository pengaturan
    // yang sudah diubah tetap utuh (inilah sumber kebocoran).
    await getIt.reset();

    expect(repository.settings.allDayReminderHourMinutes, 999);
  });
}
