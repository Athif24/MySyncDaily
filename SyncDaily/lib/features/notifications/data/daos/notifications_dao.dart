import 'package:drift/drift.dart';
import 'package:sync_daily/core/database/app_database.dart';
import 'package:sync_daily/features/notifications/data/database/app_notifications_table.dart';

part 'notifications_dao.g.dart';

@DriftAccessor(tables: [AppNotifications])
class NotificationsDao extends DatabaseAccessor<AppDatabase>
    with _$NotificationsDaoMixin {
  NotificationsDao(super.db);

  Stream<List<AppNotificationRow>> watchNotifications() {
    final query = select(appNotifications)
      ..where((n) => n.deletedAt.isNull())
      ..orderBy([(n) => OrderingTerm.desc(n.createdAt)]);
    return query.watch();
  }

  Stream<int> watchUnreadCount() {
    final count = appNotifications.id.count();
    final query = selectOnly(appNotifications)
      ..addColumns([count])
      ..where(appNotifications.deletedAt.isNull() &
          appNotifications.isRead.equals(false));
    return query.map((row) => row.read(count) ?? 0).watchSingle();
  }

  Future<void> upsertNotification(AppNotificationsCompanion companion) {
    return into(appNotifications).insertOnConflictUpdate(companion);
  }

  /// Menyisipkan baris bila `id`-nya belum ada; baris yang sudah ada TIDAK
  /// disentuh (mempertahankan `isRead`). Dipakai rekonsiliasi riwayat.
  Future<void> insertIfAbsent(AppNotificationsCompanion companion) async {
    await into(appNotifications)
        .insert(companion, mode: InsertMode.insertOrIgnore);
  }

  /// Menghapus permanen riwayat yang lama.
  ///
  /// 1. Baris lebih tua dari [olderThan] dibuang.
  /// 2. Bila jumlah baris masih melebihi [maxEntries], buang yang paling tua
  ///    selama usianya lebih tua dari [keepNewerThan] (batas jendela lookback),
  ///    supaya entri yang baru dibentuk/ditelusuri tidak ikut terhapus.
  Future<void> pruneHistory({
    required DateTime olderThan,
    required DateTime keepNewerThan,
    required int maxEntries,
  }) async {
    await (delete(appNotifications)
          ..where((n) => n.createdAt.isSmallerThanValue(olderThan)))
        .go();

    final countExpression = appNotifications.id.count();
    final count = await (selectOnly(appNotifications)
          ..addColumns([countExpression]))
        .map((row) => row.read(countExpression) ?? 0)
        .getSingle();
    if (count <= maxEntries) {
      return;
    }

    final excess = count - maxEntries;
    final oldest = await (select(appNotifications)
          ..where((n) => n.createdAt.isSmallerThanValue(keepNewerThan))
          ..orderBy([(n) => OrderingTerm.asc(n.createdAt)])
          ..limit(excess))
        .map((row) => row.id)
        .get();
    if (oldest.isEmpty) {
      return;
    }
    await (delete(appNotifications)..where((n) => n.id.isIn(oldest))).go();
  }

  Future<void> markRead(String id, DateTime now) {
    return (update(appNotifications)..where((n) => n.id.equals(id))).write(
      AppNotificationsCompanion(
        isRead: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> markAllRead(DateTime now) {
    return (update(appNotifications)
          ..where((n) => n.isRead.equals(false) & n.deletedAt.isNull()))
        .write(
      AppNotificationsCompanion(
        isRead: const Value(true),
        updatedAt: Value(now),
      ),
    );
  }

  Future<void> softDeleteNotification(String id, DateTime now) {
    return (update(appNotifications)..where((n) => n.id.equals(id))).write(
      AppNotificationsCompanion(
        deletedAt: Value(now),
        updatedAt: Value(now),
      ),
    );
  }
}
