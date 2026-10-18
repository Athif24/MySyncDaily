/// Izin yang dibutuhkan agar pengingat dapat berbunyi.
abstract class ReminderPermissions {
  /// Apakah notifikasi aplikasi sedang aktif.
  Future<bool> notificationsEnabled();

  /// Meminta izin notifikasi (Android 13+). Mengembalikan true bila notifikasi
  /// aktif setelah permintaan (termasuk bila memang sudah aktif sebelumnya,
  /// atau perangkat tidak memerlukan izin).
  Future<bool> ensureNotificationPermission();

  /// Apakah aplikasi boleh memakai alarm tepat waktu.
  Future<bool> canScheduleExactAlarms();

  /// Membuka permintaan izin alarm tepat waktu (layar khusus Android 12+).
  Future<void> requestExactAlarmsPermission();

  /// Membuka layar pengaturan aplikasi agar pengguna bisa mengaktifkan izin.
  Future<void> openSettings();
}
