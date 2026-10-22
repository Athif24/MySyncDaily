import 'package:sync_daily/core/di/injection.dart';
import 'package:sync_daily/core/router/app_router.dart';
import 'package:sync_daily/features/settings/domain/app_settings_repository.dart';

/// Mengembalikan state global yang hidup di luar widget tree ke kondisi awal.
///
/// Dua singleton bertahan selama satu berkas tes dijalankan (satu isolate):
///
/// - `AppRouter.router`: lokasi dan tumpukan rute terakhir tes sebelumnya ikut
///   terpakai lagi saat `SyncDailyApp` dipompa, sehingga layar awal bisa bukan
///   Beranda (mis. tes yang berakhir di tab Kalender).
/// - `getIt`: instance singleton dengan keadaan sesi (mis. `CalendarSelection`
///   yang menyimpan tanggal terpilih di Kalender) tetap ada sampai direset.
///
/// Karena itu tes dengan urutan acak bisa saling mempengaruhi. Panggil helper
/// ini di `setUp`, **sebelum** menyiapkan dependensi:
///
/// ```dart
/// setUp(() async {
///   await resetGlobalTestState();
///   db = await setUpInMemoryDependencies();
/// });
/// ```
Future<void> resetGlobalTestState() async {
  // Router: buang tumpukan rute sisa tes sebelumnya dan mulai dari Beranda.
  // Aman dipanggil sebelum ada widget `Router` yang terpasang; konfigurasi baru
  // langsung dipakai saat `SyncDailyApp` dipompa.
  AppRouter.router.go('/home');

  // Pengaturan: pastikan kembali ke bawaan supaya tidak bocor antar tes.
  if (getIt.isRegistered<AppSettingsRepository>()) {
    try {
      await getIt<AppSettingsRepository>().reset();
    } catch (_) {
      // Abaikan kegagalan reset; getIt.reset() di bawah tetap menjamin kebersihan.
    }
  }

  // Buang seluruh pendaftaran get_it supaya singleton berkeadaan (termasuk
  // `CalendarSelection`) dibuat ulang, bukan mewarisi nilai tes sebelumnya.
  await getIt.reset();
}
