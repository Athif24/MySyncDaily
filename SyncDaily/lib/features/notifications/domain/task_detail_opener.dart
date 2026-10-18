/// Membuka detail tugas dari notifikasi pengingat.
///
/// Dipisah dari widget agar handler respons bisa diuji tanpa membangun router
/// sungguhan.
abstract class TaskDetailOpener {
  /// Membuka detail tugas [taskId].
  ///
  /// Harus idempoten: bila detail tugas yang sama sudah menjadi layar teratas,
  /// tidak membuka lagi sehingga tombol kembali tetap kembali satu langkah.
  void open(String taskId);
}
