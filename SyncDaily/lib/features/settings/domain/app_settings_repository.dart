import 'dart:async';

import 'package:sync_daily/features/settings/domain/app_settings.dart';

abstract class AppSettingsRepository {
  AppSettings get settings;
  Stream<AppSettings> get stream;
  Future<void> init();
  Future<void> update(AppSettings settings);

  /// Mengembalikan pengaturan ke keadaan awal (bawaan).
  ///
  /// Dipakai helper reset tes (`test/helpers/reset_app_state.dart`) supaya
  /// keadaan pengaturan tidak bocor dari satu tes ke tes berikutnya.
  Future<void> reset();
}
