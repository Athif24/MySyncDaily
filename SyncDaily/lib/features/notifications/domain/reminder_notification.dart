/// Nilai-nilai yang dipakai bersama oleh perencana, penyinkron, dan
/// penjadwal notifikasi. Semuanya murni (tanpa plugin) supaya bisa diuji.
library;

/// Satu notifikasi pengingat yang harus dipasang di perangkat.
class ReminderNotification {
  /// ID notifikasi Android (31 bit positif, lihat [ReminderNotificationId]).
  final int id;
  final String taskId;

  /// ID pengingat asal (null untuk notifikasi uji/tunda).
  final String? reminderId;

  /// Waktu kemunculan yang jadi dasar (null untuk notifikasi uji/tunda).
  final DateTime? occurrence;
  final String title;
  final String body;

  /// Instan waktu notifikasi harus muncul (boleh UTC maupun lokal; yang
  /// penting instan-nya).
  final DateTime fireAt;

  /// True untuk notifikasi hasil aksi "Tunda 10 menit". Saat sinkronisasi,
  /// notifikasi tunda TIDAK dibatalkan selama tugasnya masih aktif, supaya
  /// membuka aplikasi tidak menghapus tunda yang belum berbunyi.
  final bool isSnooze;

  const ReminderNotification({
    required this.id,
    required this.taskId,
    this.reminderId,
    this.occurrence,
    required this.title,
    required this.body,
    required this.fireAt,
    this.isSnooze = false,
  });
}

/// Notifikasi pengingat yang saat ini masih tertunda di sistem operasi,
/// direkonstruksi dari payload notifikasi.
class PendingReminder {
  final int id;
  final String? taskId;
  final bool isSnooze;

  const PendingReminder({required this.id, this.taskId, this.isSnooze = false});
}

/// Interaksi pengguna dengan notifikasi pengingat (ketuk atau aksi).
class ReminderResponse {
  /// ID notifikasi Android yang memicu respons ini (0 bila tidak diketahui).
  final int notificationId;
  final String taskId;

  /// ID pengingat asal, bila payload memuatnya.
  final String? reminderId;

  /// Waktu kemunculan dasar, bila payload memuatnya.
  final DateTime? occurrence;

  /// True bila respons berasal dari notifikasi tunda.
  final bool isSnooze;

  /// ID aksi yang ditekan ([ReminderAction.done]/[ReminderAction.snooze]),
  /// atau null bila notifikasinya sendiri yang diketuk.
  final String? actionId;

  const ReminderResponse({
    this.notificationId = 0,
    required this.taskId,
    this.reminderId,
    this.occurrence,
    this.isSnooze = false,
    this.actionId,
  });

  /// Kunci unik untuk memastikan satu respons hanya ditangani sekali.
  ///
  /// Dibentuk dari ID notifikasi, ID aksi, dan isi payload. Dua pengiriman
  /// respons yang sama (mis. lewat callback plugin dan pembacaan peluncuran
  /// aplikasi) menghasilkan kunci yang sama sehingga penanganan kedua bisa
  /// diabaikan.
  String get signature => '<$notificationId|${actionId ?? ''}|$taskId|'
      '${reminderId ?? ''}|'
      '${occurrence?.toUtc().millisecondsSinceEpoch ?? ''}|'
      '${isSnooze ? 1 : 0}>';
}

/// ID aksi tombol pada notifikasi.
class ReminderAction {
  const ReminderAction._();

  static const String done = 'done';
  static const String snooze = 'snooze';
}

/// Akses tingkat rendah ke penjadwal notifikasi perangkat.
///
/// Implementasi nyata (`LocalReminderScheduler`) membungkus
/// `flutter_local_notifications`; pengujian memakai penjadwal palsu.
abstract class ReminderScheduler {
  /// Menyiapkan plugin dan memasang penangan interaksi. [onResponse] dipanggil
  /// di isolate utama saat pengguna mengetuk notifikasi atau tombol aksinya.
  Future<void> initialize({void Function(ReminderResponse response)? onResponse});

  /// Interaksi yang membuka aplikasi dari kondisi tertutup (cold start), bila
  /// ada.
  Future<ReminderResponse?> launchResponse();

  /// Seluruh notifikasi pengingat yang masih tertunda.
  Future<List<PendingReminder>> pendingReminders();

  /// Memasang (atau menimpa, karena ID sama) satu notifikasi.
  Future<void> schedule(ReminderNotification notification);

  Future<void> cancel(int id);

  Future<void> cancelAll();

  /// Menjadwalkan notifikasi uji (hanya dipakai dari galeri debug).
  Future<void> scheduleTest({Duration delay});
}
