/// ID notifikasi deterministik.
///
/// Android memakai `int` 32 bit untuk ID notifikasi, jadi nilai dijaga tetap
/// 31 bit (selalu positif). ID dihitung dari data (task + pengingat +
/// kemunculan) sehingga sinkronisasi berikutnya menghasilkan ID yang sama dan
/// `zonedSchedule` menimpa, bukan menggandakan, notifikasi.
class ReminderNotificationId {
  const ReminderNotificationId._();

  /// ID acuan untuk notifikasi uji dari galeri debug.
  static const String testTaskId = '__debug_test__';

  static const int _fnvOffset = 0x811c9dc5;
  static const int _fnvPrime = 0x01000193;
  static const int _mask31 = 0x7fffffff;

  /// ID untuk satu kemunculan pengingat.
  static int forOccurrence({
    required String taskId,
    required String reminderId,
    required DateTime occurrence,
  }) {
    return _hash(
      '$taskId|$reminderId|${occurrence.toUtc().millisecondsSinceEpoch}',
    );
  }

  /// ID untuk notifikasi tunda.
  ///
  /// Sengaja TIDAK memakai waktu, supaya menekan "Tunda 10 menit" berkali-kali
  /// untuk tugas yang sama menimpa jadwal tunda sebelumnya (satu jadwal tunda
  /// per tugas) alih-alih menggandakannya.
  static int forSnooze({required String taskId}) => _hash('$taskId|snooze');

  /// ID untuk notifikasi uji.
  static int forTest() => _hash('$testTaskId|test');

  /// FNV-1a 32 bit, dipangkas ke 31 bit.
  static int _hash(String key) {
    var hash = _fnvOffset;
    for (final unit in key.codeUnits) {
      hash ^= unit;
      hash = (hash * _fnvPrime) & 0xffffffff;
    }
    return hash & _mask31;
  }
}
