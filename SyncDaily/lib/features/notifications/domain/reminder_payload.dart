import 'dart:convert';

/// Payload JSON yang ditempelkan pada tiap notifikasi pengingat.
///
/// Payload ini menggantikan tabel database: saat sinkronisasi, aplikasi bisa
/// memetakan notifikasi yang tertunda kembali ke tugasnya (dan menandai mana
/// yang notifikasi tunda) hanya dari payload. Kunci dibuat pendek agar hemat.
class ReminderPayload {
  final String taskId;
  final String? reminderId;

  /// Waktu kemunculan (UTC) yang jadi dasar notifikasi ini.
  final DateTime? occurrence;
  final bool isSnooze;

  const ReminderPayload({
    required this.taskId,
    this.reminderId,
    this.occurrence,
    this.isSnooze = false,
  });

  String encode() {
    return jsonEncode({
      't': taskId,
      if (reminderId != null) 'r': reminderId,
      if (occurrence != null) 'o': occurrence!.toUtc().millisecondsSinceEpoch,
      if (isSnooze) 's': true,
    });
  }

  /// Mengurai payload; mengembalikan null bila bukan payload pengingat yang
  /// sah (mis. notifikasi lain atau payload rusak).
  static ReminderPayload? tryParse(String? raw) {
    if (raw == null || raw.isEmpty) {
      return null;
    }
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        return null;
      }
      final taskId = decoded['t'];
      if (taskId is! String || taskId.isEmpty) {
        return null;
      }
      final reminderId = decoded['r'];
      final epoch = decoded['o'];
      return ReminderPayload(
        taskId: taskId,
        reminderId: reminderId is String ? reminderId : null,
        occurrence: epoch is int
            ? DateTime.fromMillisecondsSinceEpoch(epoch, isUtc: true)
            : null,
        isSnooze: decoded['s'] == true,
      );
    } on FormatException {
      return null;
    }
  }
}
