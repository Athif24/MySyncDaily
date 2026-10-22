import 'dart:async';

import 'package:sync_daily/features/settings/domain/app_settings.dart';

abstract class AppSettingsRepository {
  AppSettings get settings;
  Stream<AppSettings> get stream;
  Future<void> init();
  Future<void> update(AppSettings settings);
}
