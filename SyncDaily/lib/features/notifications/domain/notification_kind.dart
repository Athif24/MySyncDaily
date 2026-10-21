import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';

/// Jenis notifikasi pada chip filter layar Notifikasi.
///
/// Chip "Pesan" belum ditampilkan karena fitur chat belum ada; sembunyikan dulu
/// sampai chat dibuat (lihat docs/DESIGN.md butir 6).
enum NotificationKind {
  reminder,
  deadline;

  /// Label chip.
  String get label {
    switch (this) {
      case NotificationKind.reminder:
        return AppStrings.notificationKindReminder;
      case NotificationKind.deadline:
        return AppStrings.notificationKindDeadline;
    }
  }

  /// Tipe notifikasi tersimpan yang masuk ke jenis ini.
  Set<NotificationType> get types {
    switch (this) {
      case NotificationKind.reminder:
        return const {NotificationType.reminder, NotificationType.event};
      case NotificationKind.deadline:
        return const {NotificationType.deadline};
    }
  }

  bool matches(NotificationType type) => types.contains(type);
}
