import 'package:sync_daily/features/notifications/domain/reminder_notification.dart';
import 'package:sync_daily/features/notifications/presentation/reminder_response_handler.dart';

/// Mengoordinasikan notifikasi yang membuka aplikasi dengan siklus hidup.
///
/// `getNotificationAppLaunchDetails` pada Android membaca intent Aktivitas yang
/// masih tersimpan, sehingga nilainya bisa tetap "membuka aplikasi" sepanjang
/// sesi dan membuat ketukan lama diproses ulang tiap aplikasi dilanjutkan.
/// [consume] memastikan respons peluncuran dibaca dan ditangani SATU kali saja.
class ReminderLaunchConsumer {
  final ReminderScheduler _scheduler;
  final ReminderResponseHandler _handler;

  bool _consumed = false;

  ReminderLaunchConsumer({
    required ReminderScheduler scheduler,
    required ReminderResponseHandler handler,
  })  : _scheduler = scheduler,
        _handler = handler;

  /// Membaca notifikasi pembuka aplikasi (bila belum pernah dibaca) dan
  /// menanganinya. Panggilan berikutnya tidak melakukan apa pun.
  Future<void> consume() async {
    if (_consumed) {
      return;
    }
    _consumed = true;
    final response = await _scheduler.launchResponse();
    if (response != null) {
      await _handler.handle(response);
    }
  }
}
