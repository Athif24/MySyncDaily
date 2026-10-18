import 'package:drift/native.dart';
import 'package:sync_daily/core/database/app_database.dart';
import 'package:sync_daily/core/di/injection.dart';

import 'fake_reminder_scheduler.dart';

/// Menyiapkan get_it dengan database Drift in-memory untuk pengujian.
///
/// Penjadwal notifikasi dan izin diganti tiruan agar plugin
/// `flutter_local_notifications` (yang butuh kanal platform) tidak dipanggil
/// dari lingkungan pengujian.
Future<AppDatabase> setUpInMemoryDependencies() async {
  await getIt.reset();
  final database = AppDatabase(NativeDatabase.memory());
  await configureDependencies(
    database: database,
    reminderScheduler: FakeReminderScheduler(),
    reminderPermissions: FakeReminderPermissions(),
  );
  return database;
}
