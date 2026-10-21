import 'dart:async';

import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';
import 'package:sync_daily/features/notifications/domain/repositories/notification_repository.dart';

/// Repository notifikasi tiruan berbasis memori untuk pengujian.
///
/// Meniru perilaku penting repository Drift:
/// - `insertIfAbsent` TIDAK menimpa baris yang sudah ada (status dibaca aman),
/// - `watchNotifications` memancarkan nilai sekarang lalu setiap perubahan
///   (setiap pendengar dapat snapshot awal, bukan hanya perubahan berikutnya),
/// - `watchUnreadCount` mengikuti jumlah belum dibaca.
class FakeNotificationRepository implements NotificationRepository {
  final Map<String, AppNotification> _rows = <String, AppNotification>{};
  final StreamController<void> _changes = StreamController<void>.broadcast();

  final List<String> markedRead = <String>[];
  int markAllReadCalls = 0;
  int pruneCalls = 0;

  Future<void> dispose() => _changes.close();

  /// Menyisipkan/ mengganti sebuah baris (dipakai penyiapan tes).
  void seed(AppNotification notification) {
    _rows[notification.id] = notification;
    _notify();
  }

  void _notify() {
    if (!_changes.isClosed) {
      _changes.add(null);
    }
  }

  List<AppNotification> _snapshot() {
    final rows = _rows.values.where((row) => !row.isDeleted).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return rows;
  }

  int _unreadCount() =>
      _rows.values.where((row) => !row.isDeleted && !row.isRead).length;

  @override
  Stream<List<AppNotification>> watchNotifications() async* {
    yield _snapshot();
    yield* _changes.stream.map((_) => _snapshot());
  }

  @override
  Stream<int> watchUnreadCount() async* {
    yield _unreadCount();
    yield* _changes.stream.map((_) => _unreadCount());
  }

  @override
  Future<void> upsertNotification(AppNotification notification) async {
    _rows[notification.id] = notification;
    _notify();
  }

  @override
  Future<void> insertIfAbsent(AppNotification notification) async {
    if (_rows.containsKey(notification.id)) {
      return;
    }
    _rows[notification.id] = notification;
    _notify();
  }

  @override
  Future<void> pruneHistory({
    required DateTime olderThan,
    required DateTime keepNewerThan,
    required int maxEntries,
  }) async {
    pruneCalls++;
    _rows.removeWhere((_, row) => row.createdAt.isBefore(olderThan));
    _notify();
  }

  @override
  Future<void> markRead(String id) async {
    markedRead.add(id);
    final row = _rows[id];
    if (row == null || row.isRead) {
      return;
    }
    _rows[id] = _copyWithRead(row);
    _notify();
  }

  @override
  Future<void> markAllRead() async {
    markAllReadCalls++;
    var changed = false;
    for (final id in _rows.keys.toList()) {
      final row = _rows[id]!;
      if (!row.isRead) {
        _rows[id] = _copyWithRead(row);
        changed = true;
      }
    }
    if (changed) {
      _notify();
    }
  }

  @override
  Future<void> softDeleteNotification(String id) async {
    final row = _rows[id];
    if (row == null) {
      return;
    }
    final now = DateTime.now().toUtc();
    _rows[id] = AppNotification(
      id: row.id,
      type: row.type,
      title: row.title,
      body: row.body,
      entityType: row.entityType,
      entityId: row.entityId,
      scheduledAt: row.scheduledAt,
      isRead: row.isRead,
      createdAt: row.createdAt,
      updatedAt: now,
      deletedAt: now,
    );
    _notify();
  }

  AppNotification _copyWithRead(AppNotification row) => AppNotification(
        id: row.id,
        type: row.type,
        title: row.title,
        body: row.body,
        entityType: row.entityType,
        entityId: row.entityId,
        scheduledAt: row.scheduledAt,
        isRead: true,
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
        deletedAt: row.deletedAt,
      );
}
