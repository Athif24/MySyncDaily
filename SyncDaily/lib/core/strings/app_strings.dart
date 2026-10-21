/// Seluruh teks UI aplikasi (Bahasa Indonesia) agar mudah diubah di satu
/// tempat, sesuai AGENTS.md.
///
/// Layar baru WAJIB memakai kelas ini, bukan menulis teks langsung di widget.
class AppStrings {
  const AppStrings._();

  // Sapaan Beranda (lihat `core/utils/greeting.dart`).
  static const String greetingMorning = 'Selamat pagi';
  static const String greetingAfternoon = 'Selamat siang';
  static const String greetingEvening = 'Selamat sore';
  static const String greetingNight = 'Selamat malam';

  // Label navigasi bawah dan judul halaman (dipakai bersama).
  static const String screenHome = 'Beranda';
  static const String screenChat = 'Pesan';
  static const String screenNotes = 'Catatan';
  static const String screenCalendar = 'Kalender';
  static const String navClose = 'Tutup';
  static const String unreadIndicator = 'Belum dibaca';

  // Panel "Buat Baru" yang dibuka tombol + pada navigasi bawah.
  static const String newPanelTitle = 'Buat Baru';
  static const String newPanelTask = 'Tugas';
  static const String newPanelEvent = 'Acara';
  static const String newPanelReminder = 'Pengingat';
  static const String newPanelMilestone = 'Milestone';
  static const String newPanelNote = 'Catatan';
  static const String newPanelProject = 'Proyek';

  // Beranda: header dan judul seksi.
  static const String notifications = 'Notifikasi';
  static const String overview = 'Ringkasan';
  static const String projects = 'Proyek';
  static const String filterPeriod = 'Filter periode';
  static const String filterProjectTime = 'Filter waktu proyek';

  // Nama bawaan pengguna.
  static const String defaultUserName = 'Pengguna';

  // Filter periode Overview.
  static const String periodThisWeek = 'Minggu ini';
  static const String periodThisMonth = 'Bulan ini';
  static const String periodAll = 'Semua';

  // Tab seksi Projects.
  static const String projectTabMine = 'Proyek saya';
  static const String projectTabReceived = 'Diterima';

  /// Contoh: `Proyek saya (3)`.
  static String tabWithCount(String tab, int count) => '$tab ($count)';

  // Kartu statistik.
  static const String statToday = 'Hari ini';
  static const String statSchedule = 'Jadwal';
  static const String statProjects = 'Proyek';
  static const String statAllTasks = 'Semua tugas';

  // Kartu proyek.
  static const String projectMenu = 'Menu proyek';
  static const String edit = 'Ubah';
  static const String delete = 'Hapus';
  static const String cancel = 'Batal';

  /// Contoh: `3 Tugas`.
  static String taskCount(int count) => '$count Tugas';

  /// Contoh: `2 Subtugas`.
  static String subtaskCount(int count) => '$count Subtugas';

  // Keadaan kosong.
  static const String noProjects = 'Belum ada proyek';
  static const String noProjectsDescription =
      'Proyek yang Anda buat akan tampil di sini.';
  static const String noReceivedProjects = 'Belum ada proyek yang diterima';
  static const String noReceivedProjectsDescription =
      'Proyek dari orang lain akan tampil di sini setelah tersinkronisasi.';
  static const String withoutDate = 'Tanpa tanggal';

  // Keadaan error.
  static const String loadFailedTitle = 'Gagal memuat data';
  static const String loadFailedDescription =
      'Terjadi kesalahan saat membaca data. Coba lagi.';
  static const String retry = 'Coba lagi';

  // Aksi yang belum tersedia.
  static const String comingSoon = 'Segera hadir';

  // Dialog hapus proyek.
  static const String deleteProjectTitle = 'Hapus proyek?';
  static String deleteProjectBody(String projectTitle) =>
      '"$projectTitle" beserta seluruh tugasnya akan dihapus.';
  static const String projectDeleted = 'Proyek dihapus';

  // Form tugas/acara/pengingat/milestone
  static const String formTitleTask = 'Tugas';
  static const String formTitleEvent = 'Acara';
  static const String formTitleReminder = 'Pengingat';
  static const String formTitleMilestone = 'Milestone';
  static const String newItem = 'Buat baru';
  static const String editItem = 'Ubah';
  static const String save = 'Simpan';
  static const String type = 'Tipe';
  static const String title = 'Judul';
  static const String description = 'Deskripsi';
  static const String priority = 'Prioritas';
  static const String project = 'Proyek';
  static const String subtask = 'Subtugas';
  static const String recurrence = 'Pengulangan';
  static const String reminderLabel = 'Pengingat';
  static const String allDay = 'Sepanjang hari';
  static const String yes = 'Ya';
  static const String startAt = 'Mulai';
  static const String endAt = 'Selesai';
  static const String dueDate = 'Tenggat';
  static const String dueTarget = 'Target';
  static const String noProject = 'Tanpa proyek';
  static const String addSubtask = 'Tambah subtugas';
  static const String titleRequired = 'Judul wajib diisi';
  static const String startRequired = 'Waktu mulai wajib diisi';
  static const String endRequired = 'Waktu selesai wajib diisi';
  static const String dueRequired = 'Tenggat wajib diisi';
  static const String endBeforeStart =
      'Waktu selesai tidak boleh sebelum waktu mulai';
  static const String none = 'Tidak';
  static const String daily = 'Harian';
  static const String weekly = 'Mingguan';
  static const String monthly = 'Bulanan';
  static const String remind10Min = '10 menit sebelum';
  static const String remind1Hour = '1 jam sebelum';
  static const String remind1Day = '1 hari sebelum';
  static const String remindOnTime = 'Tepat waktu';
  static const String priorityLow = 'Rendah';
  static const String priorityMedium = 'Sedang';
  static const String priorityHigh = 'Tinggi';
  static const String removeSubtask = 'Hapus subtugas';
  static const String editSubtask = 'Ubah subtugas';
  static const String pickDate = 'Pilih tanggal';
  static const String pickTime = 'Pilih waktu';
  static const String unsavedTitle = 'Buang perubahan?';
  static const String unsavedBody = 'Perubahan yang belum disimpan akan hilang.';
  static const String keepEditing = 'Lanjut mengubah';
  static const String discard = 'Buang';

  // Daftar tugas sementara (F4b) dan layar detail.
  static const String taskListToday = 'Hari Ini';
  static const String taskListAll = 'Semua Tugas';
  static const String back = 'Kembali';
  static const String noTasksToday = 'Belum ada item hari ini';
  static const String noTasksTodayDescription =
      'Item yang jatuh tempo hari ini akan tampil di sini.';
  static const String noAllTasks = 'Belum ada tugas';
  static const String noAllTasksDescription =
      'Tugas dan milestone yang belum selesai akan tampil di sini.';
  // Judul layar detail mengikuti tipe item (kapital di awal tiap kata).
  static const String detailTask = 'Detail Tugas';
  static const String detailEvent = 'Detail Acara';
  static const String detailReminder = 'Detail Pengingat';
  static const String detailMilestone = 'Detail Milestone';
  static const String taskNotFound = 'Item tidak ditemukan';
  static const String taskNotFoundDescription =
      'Item ini sudah dihapus atau tidak tersedia.';
  static const String markDone = 'Tandai selesai';
  static const String markUndone = 'Tandai belum selesai';
  static const String statusDone = 'Selesai';
  static const String statusNotDone = 'Belum selesai';
  static const String noDescription = 'Tanpa deskripsi';
  static const String noReminder = 'Tanpa pengingat';
  static const String noRecurrence = 'Tidak berulang';
  static const String noSubtasks = 'Tidak ada subtugas';
  static const String yearly = 'Tahunan';
  static const String deleteTaskTitle = 'Hapus tugas?';

  /// Contoh: `"Beli buku" beserta subtugasnya akan dihapus.`
  static String deleteTaskBody(String title) =>
      '"$title" beserta subtugasnya akan dihapus.';
  static const String taskDeleted = 'Tugas dihapus';
  static const String undo = 'Urungkan';

  /// Contoh: `15 menit sebelum` (offset yang tidak punya label tetap).
  static String remindMinutesBefore(int minutes) => '$minutes menit sebelum';

  // Kalender (F5).
  static const String previousMonth = 'Bulan sebelumnya';
  static const String nextMonth = 'Bulan berikutnya';
  static const String calendarTodaySection = 'Tugas Hari Ini';

  /// Contoh: `Tugas 14 Okt` (tanggal selain hari ini).
  static String calendarDateSection(String dayMonth) => 'Tugas $dayMonth';

  static const String noItemsOnDay = 'Belum ada item';
  static const String noItemsOnDayDescription =
      'Ketuk + di bawah untuk menambah item pada tanggal ini.';

  /// Label semantik panah di dasar kartu agenda bersubtugas.
  static const String showSubtasks = 'Tampilkan subtugas';
  static const String hideSubtasks = 'Sembunyikan subtugas';

  /// Subjudul kartu agenda yang punya subtugas.
  /// Contoh: `Tugas · 1/2 subtugas`.
  static String cardSubtasksSummary(String type, int done, int total) =>
      '$type · $done/$total subtugas';

  /// Contoh: `Mulai 09.00` (hari pertama acara lintas hari).
  static String startsAtTime(String clock) => 'Mulai $clock';

  /// Contoh: `Sampai 17.00` (hari terakhir acara lintas hari).
  static String endsAtTime(String clock) => 'Sampai $clock';

  // Catatan.
  static const String noteNew = 'Catatan Baru';
  static const String noteEdit = 'Ubah Catatan';
  static const String noteDetail = 'Detail Catatan';
  static const String noteContentLabel = 'Isi';
  static const String noteCategoryLabel = 'Kategori';
  static const String noteCategoryAll = 'Semua';
  static const String noteCategoryNone = 'Tanpa kategori';
  static const String noteCategoryPersonal = 'Pribadi';
  static const String noteCategoryWork = 'Pekerjaan';
  static const String noteCategoryIdea = 'Ide';
  static const String noteCategoryStudy = 'Kuliah';
  static const String noteCategoryImportant = 'Penting';
  static const String notePin = 'Sematkan';
  static const String noteViewGrid = 'Tampilan grid';
  static const String noteViewList = 'Tampilan daftar';
  static const String noteSearchHint = 'Cari catatan';
  static const String noteTitleRequired = 'Judul catatan wajib diisi';
  static const String noNoteContent = 'Tanpa isi';
  static const String noNotes = 'Belum ada catatan';
  static const String noNotesDescription =
      'Catatan yang Anda buat akan tampil di sini.';
  static const String noNotesMatch = 'Tidak ada catatan yang cocok';
  static const String noNotesMatchDescription =
      'Coba kata kunci atau kategori lain.';
  static const String deleteNoteTitle = 'Hapus catatan?';

  /// Contoh: `"Beli buku" akan dihapus.`
  static String deleteNoteBody(String title) => '"$title" akan dihapus.';
  static const String noteDeleted = 'Catatan dihapus';
  static const String noteNotFound = 'Catatan tidak ditemukan';
  static const String noteNotFoundDescription =
      'Catatan ini sudah dihapus atau tidak tersedia.';

  /// Label tanggal kartu catatan untuk catatan yang diperbarui hari ini.
  static const String noteUpdatedToday = 'Hari ini';

  /// Label tanggal kartu catatan untuk catatan yang diperbarui kemarin.
  static const String noteUpdatedYesterday = 'Kemarin';

  // Notifikasi pengingat (F8a).
  static const String reminderChannelName = 'Pengingat';
  static const String reminderChannelDescription =
      'Pengingat tugas, acara, dan milestone.';
  static const String notificationActionDone = 'Selesai';
  static const String notificationActionSnooze = 'Tunda 10 menit';
  static const String notificationSnoozedBody = 'Ditunda 10 menit';
  static const String notificationTestTitle = 'Uji notifikasi pengingat';
  static const String notificationTestBody =
      'Notifikasi uji berhasil dijadwalkan.';

  /// Konfirmasi singkat setelah aksi pada notifikasi.
  static const String notificationDoneConfirmation = 'Tugas ditandai selesai';
  static const String notificationSnoozedConfirmation =
      'Pengingat ditunda 10 menit';

  /// Isi notifikasi pengingat. Contoh: `Pengingat · 10 menit sebelum`.
  static String reminderNotificationBody(int offsetMinutes) =>
      '$reminderLabel · ${reminderOffsetLabel(offsetMinutes)}';

  // Layar Notifikasi (F8b).
  static const String notificationMarkAllRead = 'Tandai dibaca';
  static const String notificationKindAll = 'Semua';
  static const String notificationKindReminder = 'Pengingat';
  static const String notificationKindDeadline = 'Deadline';
  static const String notificationEmpty = 'Belum ada notifikasi';
  static const String notificationEmptyDescription =
      'Pengingat yang sudah berbunyi akan tampil di sini.';
  static const String notificationNoMatch = 'Tidak ada notifikasi yang cocok';
  static const String notificationNoMatchDescription =
      'Coba pilih jenis notifikasi lain.';
  static const String notificationGroupToday = 'Hari Ini';
  static const String notificationGroupYesterday = 'Kemarin';

  /// Label offset pengingat yang dipakai di notifikasi.
  static String reminderOffsetLabel(int offsetMinutes) {
    switch (offsetMinutes) {
      case 0:
        return remindOnTime;
      case 10:
        return remind10Min;
      case 60:
        return remind1Hour;
      case 1440:
        return remind1Day;
      default:
        return remindMinutesBefore(offsetMinutes);
    }
  }

  // Izin notifikasi & alarm tepat waktu (F8a).
  static const String permissionTitle = 'Izinkan notifikasi';
  static const String permissionBody =
      'SyncDaily perlu izin notifikasi agar pengingat tugas, acara, dan '
      'milestone bisa muncul meski aplikasi sedang ditutup.';
  static const String permissionExactTitle = 'Izinkan alarm tepat waktu';
  static const String permissionExactBody =
      'Agar pengingat muncul tepat pada waktunya, izinkan SyncDaily memakai '
      'alarm dan pengingat. Tanpa izin ini, pengingat bisa muncul sedikit '
      'terlambat.';
  static const String permissionOemNote =
      'Jika notifikasi tetap tidak muncul, sebagian ponsel (mis. Samsung, '
      'Xiaomi, Oppo, Vivo) membatasi aplikasi di latar belakang.';
  static const String permissionOpenSettings = 'Buka pengaturan';
  static const String permissionLater = 'Nanti';

  // Panduan OEM agar pengingat tidak terlewat.
  static const String oemGuideLink = 'Panduan agar pengingat tidak terlewat';
  static const String oemGuideTitle = 'Panduan agar pengingat tidak terlewat';
  static const String oemGuideIntro =
      'Sebagian ponsel membatasi aplikasi di latar belakang sehingga '
      'notifikasi bisa tertunda atau tidak muncul. Lakukan langkah berikut '
      'pada pengaturan ponsel Anda:';
  static const List<String> oemGuideSteps = [
    'Buka Pengaturan ponsel, lalu pilih Aplikasi > SyncDaily.',
    'Nyalakan Notifikasi untuk SyncDaily.',
    'Izinkan alarm dan pengingat bila ada pilihannya.',
    'Matikan pembatasan baterai untuk SyncDaily (pada Samsung: Baterai > '
        'Batasi penggunaan baterai).',
    'Pada Samsung, pastikan SyncDaily tidak masuk daftar "Aplikasi tidur" '
        '(Pengaturan > Baterai > Aplikasi tidur).',
    'Nyalakan Autostart atau jalankan otomatis untuk SyncDaily bila ada.',
  ];
  static const String oemGuideDismiss = 'Mengerti';
}
