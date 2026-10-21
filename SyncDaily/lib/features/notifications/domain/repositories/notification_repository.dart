import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';

abstract class NotificationRepository {
  Stream<List<AppNotification>> watchNotifications();

  /// Jumlah notifikasi belum dibaca (badge lonceng).
  Stream<int> watchUnreadCount();

  Future<void> upsertNotification(AppNotification notification);

  /// Menyisipkan [notification] bila `id`-nya belum ada; baris yang sudah ada
  /// TIDAK ditimpa sehingga status dibaca tidak hilang. Dipakai rekonsiliasi
  /// riwayat notifikasi yang idempoten.
  Future<void> insertIfAbsent(AppNotification notification);

  /// Menghapus permanen riwayat lama: lebih tua dari [olderThan], lalu
  /// menyisakan paling banyak [maxEntries] tanpa menyentuh entri yang lebih
  /// baru dari [keepNewerThan].
  Future<void> pruneHistory({
    required DateTime olderThan,
    required DateTime keepNewerThan,
    required int maxEntries,
  });

  Future<void> markRead(String id);

  Future<void> markAllRead();

  Future<void> softDeleteNotification(String id);
}
