import 'package:flutter/foundation.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/features/notifications/domain/app_messenger.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_id.dart';
import 'package:sync_daily/features/notifications/domain/reminder_notification.dart';
import 'package:sync_daily/features/notifications/domain/reminder_response_deduplicator.dart';
import 'package:sync_daily/features/notifications/domain/reminder_synchronizer.dart';
import 'package:sync_daily/features/notifications/domain/repositories/notification_repository.dart';
import 'package:sync_daily/features/notifications/domain/task_detail_opener.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/domain/repositories/task_repository.dart';

/// Menangani interaksi pengguna dengan notifikasi pengingat.
///
/// Aturan:
/// - Mengetuk BADAN notifikasi membuka detail tugas (idempoten).
/// - Tombol "Selesai" menandai tugas selesai; TIDAK membuka layar apa pun.
/// - Tombol "Tunda 10 menit" menjadwalkan ulang; TIDAK membuka layar apa pun.
/// - Setiap respons hanya ditangani sekali (lihat [ReminderResponseDeduplicator])
///   agar ketukan yang dikirim lewat beberapa jalur tidak diproses berulang.
/// - Ketukan badan maupun aksi menandai entri riwayat yang bersangkutan dibaca
///   (bila ada). Rekonsiliasi riwayat dijalankan lebih dulu di siklus hidup
///   aplikasi (`main.dart`) agar entri sudah terbentuk saat langkah ini jalan.
class ReminderResponseHandler {
  final ReminderSynchronizer _synchronizer;
  final TaskRepository _taskRepository;
  final TaskDetailOpener _opener;
  final AppMessenger _messenger;
  final NotificationRepository _notificationRepository;
  final ReminderResponseDeduplicator _deduplicator;

  ReminderResponseHandler({
    required ReminderSynchronizer synchronizer,
    required TaskRepository taskRepository,
    required TaskDetailOpener opener,
    required AppMessenger messenger,
    required NotificationRepository notificationRepository,
    ReminderResponseDeduplicator? deduplicator,
  })  : _synchronizer = synchronizer,
        _taskRepository = taskRepository,
        _opener = opener,
        _messenger = messenger,
        _notificationRepository = notificationRepository,
        _deduplicator = deduplicator ?? ReminderResponseDeduplicator();

  Future<void> handle(ReminderResponse response) async {
    if (!_deduplicator.shouldHandle(response.signature)) {
      return;
    }
    try {
      switch (response.actionId) {
        case ReminderAction.done:
          await _taskRepository.setStatus(response.taskId, TaskStatus.done);
          await _markHistoryRead(response);
          _messenger.showSnackBar(AppStrings.notificationDoneConfirmation);
        case ReminderAction.snooze:
          await _synchronizer.snooze(response.taskId);
          await _markHistoryRead(response);
          _messenger.showSnackBar(AppStrings.notificationSnoozedConfirmation);
        default:
          await _markHistoryRead(response);
          _opener.open(response.taskId);
      }
    } catch (error) {
      debugPrint('[SyncDaily] Gagal menangani aksi notifikasi: $error');
    }
  }

  /// Menandai entri riwayat kemunculan ini dibaca. Tidak melakukan apa pun bila
  /// payload tidak memuat pengingat/kemunculan (mis. notifikasi tunda) atau
  /// bila entrinya belum terbentuk.
  Future<void> _markHistoryRead(ReminderResponse response) async {
    final id = NotificationHistoryId.tryForResponse(response);
    if (id == null) {
      return;
    }
    await _notificationRepository.markRead(id);
  }
}
