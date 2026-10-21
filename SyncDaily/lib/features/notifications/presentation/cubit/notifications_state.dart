import 'package:equatable/equatable.dart';
import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';
import 'package:sync_daily/features/notifications/domain/notification_day_group.dart';
import 'package:sync_daily/features/notifications/domain/notification_kind.dart';

enum NotificationsStatus { loading, loaded, error }

/// Keadaan layar Notifikasi.
class NotificationsState extends Equatable {
  final NotificationsStatus status;

  /// Semua entri riwayat dari repository (belum disaring).
  final List<AppNotification> allEntries;

  /// Entri yang lolos filter jenis.
  final List<AppNotification> visibleEntries;

  /// [visibleEntries] yang sudah dikelompokkan per hari (terbaru lebih dulu).
  final List<NotificationDayGroup> groups;

  /// Jenis terpilih; `null` berarti "Semua".
  final NotificationKind? kind;

  /// Tanggal hari ini (tanpa jam) dari jam yang diinjeksi, dipakai label
  /// kelompok ("Hari Ini"/"Kemarin").
  final DateTime today;

  final String? errorMessage;

  const NotificationsState({
    this.status = NotificationsStatus.loading,
    this.allEntries = const [],
    this.visibleEntries = const [],
    this.groups = const [],
    this.kind,
    required this.today,
    this.errorMessage,
  });

  bool get isEmpty => visibleEntries.isEmpty;

  /// True bila ada filter jenis aktif sehingga keadaan kosong berarti "tidak
  /// cocok", bukan "belum ada notifikasi".
  bool get hasFilter => kind != null;

  /// True bila masih ada entri belum dibaca (dipakai untuk mengaktifkan tombol
  /// "Tandai dibaca").
  bool get hasUnread => allEntries.any((entry) => !entry.isRead);

  NotificationsState copyWith({
    NotificationsStatus? status,
    List<AppNotification>? allEntries,
    List<AppNotification>? visibleEntries,
    List<NotificationDayGroup>? groups,
    NotificationKind? kind,
    bool clearKind = false,
    DateTime? today,
    String? errorMessage,
    bool clearError = false,
  }) {
    return NotificationsState(
      status: status ?? this.status,
      allEntries: allEntries ?? this.allEntries,
      visibleEntries: visibleEntries ?? this.visibleEntries,
      groups: groups ?? this.groups,
      kind: clearKind ? null : (kind ?? this.kind),
      today: today ?? this.today,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        status,
        allEntries,
        visibleEntries,
        groups,
        kind,
        today,
        errorMessage,
      ];
}
