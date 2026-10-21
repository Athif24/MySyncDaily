# SyncDaily — Panduan Desain

Sumber kebenaran visual. Semua UI HARUS mengikuti file ini. Jika ada hal yang tidak tercakup, ikuti gaya yang sama (jangan mengarang gaya baru) dan beri tahu pengguna.
Kanvas desain: https://claude.ai/artifact/NknurSjNLv5P9bVrWiKjJ1 (tangkapan layar boleh ditaruh di `docs/design/`).

## Prinsip
- Bersih, lapang, kartu pastel bersudut membulat, aksen ungu, teks tebal dan jelas.
- Bahasa UI: Indonesia. Format tanggal dan waktu: `id_ID` (contoh: 14 Okt 2026, 11.20).
- Target sentuh minimal 44x44 dp. Kontras teks minimal 4.5:1.
- Semua warna, radius, dan ukuran teks diambil dari theme. Dilarang menulis nilai hex atau ukuran langsung di widget.

## Warna
| Token | Nilai | Pemakaian |
|---|---|---|
| primary | #6C47FF | aksen, item nav aktif, titik belum dibaca, badge |
| primaryDark | #5B3FD6 | teks aksen, ujung gradasi |
| primaryGradient | #8E70FF -> #5B3FD6 (145 derajat) | tombol + |
| ink | #141318 | teks utama, chip aktif, tombol hitam |
| textSecondary | #4A475E | teks sekunder |
| textMuted | #6B6880 | caption, waktu, placeholder |
| border | #E6E3F5 | garis chip, kolom cari, tombol bulat |
| borderSoft | #ECE9F7 | garis kartu |
| surface | #FFFFFF | kartu, nav |
| pageBackground | gradasi vertikal #EEEBFF -> #FFFFFF sampai 40% tinggi layar | latar semua layar |
| navActiveBg | #F0ECFF | latar ikon nav aktif |
| unreadBg / unreadBorder | #F3F0FF / #E0D9FF | latar item belum dibaca |

Warna kategori (latar / ikon dan label):
| Kategori | Latar | Ikon |
|---|---|---|
| Tugas (violet) | #E7E1FF | #5B3FD6 |
| Pengingat (oranye) | #FFE6D6 | #A64515 |
| Acara (biru) | #D9EEFB | #17608F |
| Milestone / Selesai (hijau) | #DDF3E6 | #1B6E43 |
| Catatan / Pesan lain (pink) | #FFE0EC | #A32E5F |
| Proyek (kuning) | #FFF1C9 | #7E5C00 |
| Deadline (merah) | #FFE0E6 | #B3263E |

## Tipografi
Font: Plus Jakarta Sans (400, 500, 600, 700, 800). Font DIBUNDEL di `assets/fonts` agar jalan offline.
- Judul halaman: 26-28 / 800
- Judul seksi: 18-22 / 800
- Judul kartu dan item: 14-15 / 700
- Isi: 13-14 / 500
- Caption dan waktu: 12 / 400-500, warna textMuted
- Label kategori: 11 / 700, huruf kapital, letterSpacing 0.04em

## Bentuk dan spasi
- Padding horizontal halaman: 24. Jarak antar item: 8-12.
- Radius: kartu 20-22, chip 14, kolom cari 16, kotak ikon 14-15, panel bawah 30, nav pill 34, tombol + 22.
- Bayangan nav: offset (0,8), blur 30, warna rgba(60,40,140,0.16).
- Bayangan tombol +: cincin putih 5 dp, lalu offset (0,10) blur 24 warna rgba(108,71,255,0.45).
- Ikon: garis (outline), stroke 1.8, ujung bulat. Ukuran 20-24. Tanpa emoji.

## Komponen
- **Bottom nav**: pill putih melayang. Kiri/kanan 16, bawah 20, tinggi 68. 5 slot: Beranda, Pesan, tombol +, Catatan, Kalender. Item aktif: ikon ungu dalam kotak 46x46 radius 16 berlatar navActiveBg.
- **Tombol +**: 60x60, radius 22, primaryGradient, ikon plus putih 26 (stroke 2.6), naik 14 dp dari nav. Saat panel terbuka: latar ink, ikon berputar 45 derajat (jadi x).
- **Chip filter**: padding 9x14, radius 14, teks 13/600. Aktif: latar ink, teks putih. Tidak aktif: putih, garis border.
- **Kolom cari**: tinggi 48, radius 16, putih, garis border, ikon kaca pembesar.
- **Kartu kategori**: latar warna kategori, radius 20-22, padding 14-16, label kategori + judul + keterangan.
- **Item notifikasi / chat**: kotak ikon atau avatar 44-48, judul satu baris (ellipsis), subjudul satu baris, waktu di kanan, titik atau badge ungu untuk belum dibaca.

## Layar yang sudah didesain
1. **Beranda**: sapaan + nama, ikon lonceng dengan badge jumlah belum dibaca, "Ringkasan" dengan filter (Minggu ini), 4 kartu statistik (Hari ini, Jadwal, Proyek, Semua tugas) dengan grafik garis kecil, seksi "Proyek" dengan filter waktu, tab "Proyek saya" / "Diterima", kartu proyek (chip tanggal, jumlah tugas dan subtugas, menu titik tiga: Ubah, Hapus).
2. **Kalender**: tanggal terpilih + tombol bulan sebelumnya/berikutnya, grid bulan (hari terpilih lingkaran hitam, titik kecil berwarna untuk hari yang punya item), "Tugas Hari Ini", daftar item bertipe (To Do, Event, Reminder, Milestone) dengan jam. Tidak ada tombol tambah di samping judul seksi: penambahan item lewat tombol + di navigasi bawah, yang membuka panel "Buat Baru" lalu membawa tanggal yang sedang dipilih di Kalender ke form. Kartu agenda yang punya subtugas memakai satu kartu dengan panah di dasar untuk membuka dan menutup daftar subtugas.
3. **Pesan**: judul + tombol pesan baru, kolom cari, chip (Semua, Tim, Proyek, Belum dibaca), daftar percakapan (avatar inisial berwarna, nama, pratinjau, waktu, badge).
4. **Catatan**: judul dan tombol ganti tampilan, kolom cari (tanpa fokus otomatis), chip kategori, lalu grid dua kolom kartu catatan pastel (label kategori, judul, isi singkat 3 baris, tanggal). Tidak ada tombol tambah di layar ini: penambahan catatan lewat tombol + di navigasi bawah, yang membuka panel "Buat Baru". Judul, kolom cari, dan chip kategori tetap di atas; hanya grid/daftar catatan yang bergulir (padding bawah agar kartu terakhir tidak tertutup navigasi bawah). Tampilan daftar jadi alternatif grid.
   - Lima kategori bawaan (tetap): Pribadi, Pekerjaan, Ide, Kuliah, Penting, ditambah pilihan tanpa kategori.
   - Warna kartu hanya mengikuti kategori (tidak ada pemilih warna di form) dan memakai token pastel yang sudah ada: Pribadi violet (taskBg/taskIcon), Pekerjaan biru (eventBg/eventIcon), Ide kuning (projectBg/projectIcon), Kuliah hijau (milestoneBg/milestoneIcon), Penting merah (deadlineBg/deadlineIcon), tanpa kategori pink (noteBg/noteIcon).
   - Sematan lewat toggle "Sematkan" pada form dan halaman detail. Kartu yang disematkan menampilkan ikon sematan dan selalu diurutkan lebih dulu, lalu yang paling baru diperbarui; pencarian mencocokkan judul atau isi dan digabung dengan filter kategori.
5. **Buat baru**: latar gelap blur, panel bawah "Buat Baru" berisi 6 ubin: Tugas, Acara, Pengingat, Milestone, Catatan, Proyek. Ubin Proyek tidak aktif sampai fitur proyek dibuat.
6. **Notifikasi**: tombol kembali, "Tandai dibaca", chip (Semua, Pengingat, Deadline), dikelompokkan per hari. Notifikasi pengingat punya tombol aksi "Selesai" dan "Tunda 10 menit" yang hanya tampil pada entri yang belum dibaca (hilang setelah entri dibaca atau aksinya ditekan). Chip "Pesan" disembunyikan sampai fitur chat tersedia.

## Layar yang BELUM didesain
Detail tugas, form tugas/acara/pengingat/milestone, detail proyek, ruang chat, cari pengguna, login/daftar, profil, pengaturan. Untuk layar ini: pakai komponen dan token di atas, jaga konsistensi, dan tandai di kode dengan komentar `TODO(design)`.
