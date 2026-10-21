import 'package:sync_daily/features/notifications/domain/reminder_notification.dart';

/// Nilai `entityType` entri riwayat yang berasal dari sebuah tugas/item.
const String notificationTaskEntityType = 'task';

/// Kunci unik deterministik untuk satu entri riwayat notifikasi.
///
/// Dibentuk dari data (tugas + pengingat + kemunculan) sehingga rekonsiliasi
/// berikutnya menghasilkan kunci yang sama. Karena itu penyisipan cukup "sisip
/// bila belum ada" dan tidak menimpa `isRead` entri yang sudah dibaca.
class NotificationHistoryId {
  const NotificationHistoryId._();

  /// Contoh: `reminder|t1|r1|1729000000000`.
  static String forReminder({
    required String taskId,
    required String reminderId,
    required DateTime occurrence,
  }) {
    return 'reminder|$taskId|$reminderId|'
        '${occurrence.toUtc().millisecondsSinceEpoch}';
  }

  /// Kunci entri dari sebuah respons notifikasi. `null` bila payload tidak
  /// memuat pengingat atau kemunculan (mis. notifikasi tunda), karena entri
  /// riwayat hanya dibentuk dari kemunculan pengingat.
  static String? tryForResponse(ReminderResponse response) {
    final reminderId = response.reminderId;
    final occurrence = response.occurrence;
    if (reminderId == null || occurrence == null) {
      return null;
    }
    return forReminder(
      taskId: response.taskId,
      reminderId: reminderId,
      occurrence: occurrence,
    );
  }
}
