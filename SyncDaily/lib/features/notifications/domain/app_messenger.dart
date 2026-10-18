/// Menampilkan pesan singkat (snackbar) di layar yang sedang tampil.
///
/// Dipisah dari widget agar handler respons notifikasi bisa diuji tanpa
/// membangun pohon widget.
abstract class AppMessenger {
  /// Menampilkan [message] sebagai snackbar.
  void showSnackBar(String message);
}
