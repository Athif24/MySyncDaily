import 'package:sync_daily/features/notifications/data/daos/notifications_dao.dart';
import 'package:sync_daily/features/notifications/data/mappers/app_notification_mapper.dart';
import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';
import 'package:sync_daily/features/notifications/domain/repositories/notification_repository.dart';

class NotificationRepositoryImpl implements NotificationRepository {
  final NotificationsDao _dao;

  NotificationRepositoryImpl(this._dao);

  @override
  Stream<List<AppNotification>> watchNotifications() {
    return _dao.watchNotifications().map(
          (rows) => rows.map((row) => row.toEntity()).toList(),
        );
  }

  @override
  Stream<int> watchUnreadCount() => _dao.watchUnreadCount();

  @override
  Future<void> upsertNotification(AppNotification notification) =>
      _dao.upsertNotification(notification.toCompanion());

  @override
  Future<void> insertIfAbsent(AppNotification notification) =>
      _dao.insertIfAbsent(notification.toCompanion());

  @override
  Future<void> pruneHistory({
    required DateTime olderThan,
    required DateTime keepNewerThan,
    required int maxEntries,
  }) =>
      _dao.pruneHistory(
        olderThan: olderThan,
        keepNewerThan: keepNewerThan,
        maxEntries: maxEntries,
      );

  @override
  Future<void> markRead(String id) => _dao.markRead(id, DateTime.now().toUtc());

  @override
  Future<void> markAllRead() => _dao.markAllRead(DateTime.now().toUtc());

  @override
  Future<void> softDeleteNotification(String id) =>
      _dao.softDeleteNotification(id, DateTime.now().toUtc());
}
