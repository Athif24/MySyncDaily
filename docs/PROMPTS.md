# Prompt untuk OpenCode — SyncDaily

## Cara pakai
1. File paket ini (docs/ dan AGENTS.md) dibuat oleh prompt setup (PROMPT-SETUP-OpenCode.md). Jika membuat manual: letakkan `docs/` di `MyProject/` dan `AGENTS.md` di `SyncDaily/` dan `BE-SyncDaily/`.
2. Jalankan OpenCode di folder yang sesuai: `SyncDaily` untuk Flutter, `BE-SyncDaily` untuk BackEnd. Jika OpenCode meminta izin membaca `../docs`, izinkan. Jika ditolak, salin folder `docs` ke dalam folder itu dan ubah rujukan `../docs` menjadi `docs`.
3. Mulai dengan agent Plan (tombol Tab) untuk melihat rencana, lalu pindah ke Build.cd
4. Kirim SATU prompt, jalankan aplikasinya, uji, commit ke Git, baru lanjut prompt berikutnya.
5. Cara cepat: cukup ketik `Kerjakan prompt F0 di ../docs/PROMPTS.md` (ganti F0 sesuai langkah). OpenCode akan membaca prompt itu sendiri.
6. Jika hasil belum pas, perbaiki dengan prompt kecil ("tombol + kurang naik, samakan dengan DESIGN.md"), jangan menulis ulang semuanya.

---
## FASE 1 — Aplikasi lokal (folder SyncDaily)

### F0 — Fondasi proyek
```text
Baca AGENTS.md dan ../docs/DESIGN.md.
Tujuan: siapkan fondasi proyek SyncDaily (Android saja).
Kerjakan:
1. Pastikan proyek Flutter ada di folder ini. Jika belum, usulkan perintah flutter create beserta nama paket (misal com.syncdaily.app) dan tanyakan dulu. Hapus kode counter bawaan.
2. Tambahkan dependency sesuai AGENTS.md dan struktur folder lib/core dan lib/features.
3. Bundel font Plus Jakarta Sans di assets/fonts. Jika tidak bisa mengunduh, beri tahu langkah manualnya.
4. Buat AppTheme dari token di DESIGN.md: ColorScheme, TextTheme, radius, bayangan, serta ThemeExtension untuk warna kategori.
5. Siapkan go_router dengan shell navigasi bawah (tab Beranda, Pesan, Catatan, Kalender, dan tombol + di tengah) beserta placeholder tiap layar.
Selesai jika: flutter analyze bersih, aplikasi berjalan, dan bisa pindah tab.
Jangan membuat fitur lain.
```

### F1 — Komponen bersama dan navigasi
```text
Baca AGENTS.md dan ../docs/DESIGN.md (bagian Komponen).
Buat di lib/core/widgets: AppBottomNav (pill dengan tombol + gradasi yang menonjol), AppChip, AppSearchField, CategoryCard, EmptyState, dan LayarLatar (gradasi halaman).
Hubungkan AppBottomNav ke shell go_router. Tombol + untuk sementara menampilkan snackbar.
Buat satu halaman galeri komponen (hanya debug) untuk memeriksa tampilan.
Selesai jika: tampilan nav, tombol +, dan chip sama dengan DESIGN.md; flutter analyze bersih.
```

### F2 — Database dan domain tugas
```text
Baca AGENTS.md dan ../docs/API.md (bagian model Task).
Buat database Drift: tabel tasks (type task|event|reminder|milestone, parentTaskId untuk sub-task, status, priority, startAt, endAt, dueAt, isAllDay, recurrence, reminderOffsetsMinutes, projectId opsional, remoteId opsional), projects, notes, app_notifications.
Buat entity, repository interface, implementasi, dan DAO. Siapkan query untuk: tugas hari ini, per rentang tanggal, per proyek, hitung ringkasan (Hari ini, Jadwal, Proyek, Semua tugas).
Tulis tes repository dengan database in-memory.
Selesai jika: tes lulus dan flutter analyze bersih. Belum ada UI.
```

### F3 — Beranda
```text
Baca AGENTS.md dan ../docs/DESIGN.md (layar Beranda).
Bangun layar Beranda dari data nyata: sapaan, lonceng dengan badge notifikasi belum dibaca, Overview dengan filter (minggu ini dan lainnya) dan 4 kartu statistik, seksi Projects dengan tab Proyek saya / Diterima (tab Diterima kosong dulu), kartu proyek dengan menu Edit/Hapus (dengan konfirmasi hapus).
Tambahkan seed data debug agar tampilan bisa dicek.
Selesai jika: angka kartu mengikuti database dan tampilan sama dengan DESIGN.md.
```

### F4 — Form dan detail tugas
```text
Baca AGENTS.md dan ../docs/DESIGN.md.
Layar form belum didesain: gunakan komponen yang ada dan beri komentar TODO(design).
Bangun form buat/ubah untuk tipe Tugas, Acara, Pengingat, dan Milestone (isian berbeda per tipe), sub-task, prioritas, proyek, pengulangan (tidak, harian, mingguan, bulanan), dan pilihan pengingat (misal 10 menit, 1 jam, 1 hari sebelum). Bangun layar detail tugas dengan ubah status, edit, dan hapus (konfirmasi + undo lewat snackbar).
Validasi: judul wajib, selesai tidak boleh sebelum mulai.
Selesai jika: semua tipe bisa dibuat, diubah, dan dihapus, dan muncul di Beranda.
```

### F5 — Kalender
```text
Baca AGENTS.md dan ../docs/DESIGN.md (layar Kalender).
Bangun Kalender: grid bulan (pakai paket kalender ringan jika ada yang cocok setelah bertanya kepadaku, atau buat grid sendiri), hari terpilih lingkaran hitam, titik berwarna untuk hari yang punya item, daftar Today's Task untuk tanggal terpilih dengan tombol tambah yang membuka form dengan tanggal terisi.
Tampilkan item berulang pada tanggal yang tepat.
Selesai jika: pindah bulan lancar dan daftar mengikuti tanggal.
```

### F6 — Catatan
```text
Baca AGENTS.md dan ../docs/DESIGN.md (layar Catatan).
Bangun menu Catatan: grid dua kolom kartu pastel, pencarian, chip kategori, ganti tampilan grid/daftar, serta buat/ubah/hapus catatan (judul, isi, kategori, warna, sematkan).
Selesai jika: CRUD catatan berjalan dan tersimpan offline.
```

### F7 — Tombol + (panel Buat baru)
```text
Baca AGENTS.md dan ../docs/DESIGN.md (layar Buat baru).
Implementasikan panel Buat baru: latar gelap blur, panel bawah 6 ubin (Tugas, Acara, Pengingat, Milestone, Catatan, Proyek), tombol + berputar 45 derajat menjadi x. Tiap ubin membuka form yang sesuai. Tutup dengan ketuk latar, tombol x, atau tombol kembali.
Selesai jika: animasi halus dan semua ubin menuju layar yang benar.
```

### F8 — Notifikasi lokal dan halaman Notifikasi
```text
Baca AGENTS.md dan ../docs/DESIGN.md (layar Notifikasi).
1. Layanan penjadwalan pengingat dari tugas (tanpa server): jadwalkan, batalkan, dan jadwalkan ulang saat tugas berubah; dukung pengulangan.
2. Izin Android: notifikasi (Android 13 ke atas) dan alarm tepat waktu. Jelaskan opsi yang kamu pilih sebelum menulis.
3. Pastikan jadwal kembali setelah HP restart.
4. Aksi dari notifikasi HP: "Selesai" dan "Tunda 10 menit".
5. Halaman Notifikasi: daftar per hari, filter, tandai dibaca, dan ketuk membuka tugas terkait. Lonceng di Beranda menampilkan badge.
6. Beberapa HP (misal Xiaomi dan Oppo) membatasi aplikasi di latar belakang: tambahkan panduan singkat di Pengaturan agar pengguna mengizinkan SyncDaily berjalan di latar belakang.
Selesai jika: pengingat berbunyi saat aplikasi ditutup, dan aksi Selesai/Tunda bekerja.
```

### F9 — Pencarian, filter, dan pengaturan
```text
Baca AGENTS.md.
Tambahkan pencarian dan filter di daftar semua tugas, serta layar Pengaturan sederhana (pengaturan notifikasi: jam tenang dan waktu pengingat bawaan, tema, tentang aplikasi).
Selesai jika: pencarian cepat dan pengaturan tersimpan.
```

---
## FASE 2 dan seterusnya (akan dirinci setelah Fase 1 selesai)
- **B0** (BE-SyncDaily): kerangka BackEnd siap Vercel (export default app, vercel.json, env, Prisma generate saat build), koneksi ke PostgreSQL lokal (syncdaily_dev), skema Prisma awal, error handler. Database cloud untuk produksi (Neon atau Supabase) dipilih saat B6.
- **B1**: auth (daftar, login, refresh, logout, hapus akun).
- **B2**: proyek, anggota, undangan, dan aturan izin lengkap dengan tes.
- **B3**: tugas proyek, penugasan, dan endpoint /sync.
- **B4**: perangkat dan push FCM, notifikasi server.
- **B5**: chat REST (sumber kebenaran) + realtime lewat RealtimeGateway, grup proyek otomatis, pesan tertinggal lewat ?after=.
- **F-Auth, F-Projects, F-Sync, F-Chat** (SyncDaily): layar login, proyek bersama, sinkronisasi, dan chat setelah desain layarnya selesai.
- **B6**: deploy BackEnd ke Vercel (buat database cloud PostgreSQL, jalankan migrasi produksi, env di dashboard, cron, uji endpoint produksi).
- **Rilis**: penandatanganan APK, pendaftaran Android Developer Console, website unduh, cek pembaruan.
