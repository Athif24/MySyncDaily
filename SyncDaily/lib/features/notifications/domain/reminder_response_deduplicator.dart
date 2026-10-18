/// Mencegah satu respons notifikasi ditangani lebih dari sekali.
///
/// `flutter_local_notifications` bisa mengirim ketukan yang sama lewat lebih
/// dari satu jalur: callback `onDidReceiveNotificationResponse` dan pembacaan
/// `getNotificationAppLaunchDetails`. Pembacaan peluncuran juga bisa terulang
/// tiap aplikasi dilanjutkan, karena plugin membacanya dari intent Aktivitas
/// yang masih tersimpan.
///
/// Deduplikator menyimpan tanda tangan respons yang baru ditangani selama
/// [ttl] yang singkat, lalu mengabaikan pengiriman ulang yang identik.
class ReminderResponseDeduplicator {
  /// Lama sebuah tanda tangan dianggap masih "baru".
  final Duration ttl;

  /// Menandai sudah-ditangani; dipanggil ulang tiap [shouldHandle].
  final DateTime Function() _now;

  final Map<String, DateTime> _handled = {};

  ReminderResponseDeduplicator({
    this.ttl = const Duration(seconds: 5),
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  /// True bila [signature] belum pernah ditangani (dalam rentang [ttl]).
  ///
  /// Sekaligus menandai [signature] sebagai sudah ditangani.
  bool shouldHandle(String signature) {
    final current = _now();
    _handled.removeWhere(
      (_, handledAt) => current.difference(handledAt) > ttl,
    );
    if (_handled.containsKey(signature)) {
      return false;
    }
    _handled[signature] = current;
    return true;
  }
}
