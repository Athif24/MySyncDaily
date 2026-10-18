import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:sync_daily/core/di/injection.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/core/theme/app_colors.dart';
import 'package:sync_daily/core/theme/app_icons.dart';
import 'package:sync_daily/core/theme/app_radius.dart';
import 'package:sync_daily/core/theme/app_sizes.dart';
import 'package:sync_daily/core/theme/category_theme.dart';
import 'package:sync_daily/core/widgets/app_avatar.dart';
import 'package:sync_daily/core/widgets/app_bottom_nav.dart';
import 'package:sync_daily/core/widgets/app_chip.dart';
import 'package:sync_daily/core/widgets/app_icon_button.dart';
import 'package:sync_daily/core/widgets/app_search_field.dart';
import 'package:sync_daily/core/widgets/category_card.dart';
import 'package:sync_daily/core/widgets/empty_state.dart';
import 'package:sync_daily/core/widgets/latar_layar.dart';
import 'package:sync_daily/core/widgets/list_item_tile.dart';
import 'package:sync_daily/core/widgets/section_header.dart';
import 'package:sync_daily/core/widgets/unread_badge.dart';
import 'package:sync_daily/core/widgets/unread_dot.dart';
import 'package:sync_daily/features/debug/data/debug_data_seeder.dart';
import 'package:sync_daily/features/notifications/domain/reminder_notification.dart';

class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key});

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  int currentIndex = 0;
  bool chipActive = true;
  bool navOpen = false;

  Future<void> _fillSampleData() async {
    await getIt<DebugDataSeeder>().seed();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Data contoh diisi')),
    );
  }

  Future<void> _clearAllData() async {
    await getIt<DebugDataSeeder>().clearAll();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua data dihapus')),
    );
  }

  /// Menjadwalkan notifikasi uji beberapa detik ke depan untuk memeriksa izin
  /// dan saluran notifikasi tanpa menunggu jadwal pengingat sungguhan.
  Future<void> _scheduleTestNotification() async {
    await getIt<ReminderScheduler>().scheduleTest(
      delay: const Duration(seconds: 10),
    );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.notificationTestBody)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: LayarLatar(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSizes.pagePadding),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    AppIconButton(
                      icon: AppIcons.back,
                      semanticLabel: 'Kembali',
                      onTap: () => context.canPop()
                          ? context.pop()
                          : context.go('/'),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Galeri Komponen',
                        style: Theme.of(context).textTheme.displayMedium,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const SectionHeader(title: 'Kolom Cari'),
                const SizedBox(height: 12),
                const AppSearchField(hintText: 'Cari komponen...'),
                const SizedBox(height: 24),

                const SectionHeader(title: 'Chip Filter'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    AppChip(
                      label: 'Semua',
                      isActive: chipActive,
                      onTap: () => setState(() => chipActive = !chipActive),
                    ),
                    const SizedBox(width: 8),
                    const AppChip(label: 'Tim', isActive: false),
                    const SizedBox(width: 8),
                    const AppChip(label: 'Proyek', isActive: false),
                  ],
                ),
                const SizedBox(height: 24),

                const SectionHeader(title: 'Tombol Ikon'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    AppIconButton(
                      icon: AppIcons.back,
                      semanticLabel: 'Kembali',
                      onTap: () {},
                    ),
                    const SizedBox(width: 12),
                    AppIconButton(
                      icon: AppIcons.bell,
                      semanticLabel: 'Notifikasi',
                      onTap: () {},
                    ),
                    const SizedBox(width: 12),
                    const AppIconButton(
                      icon: AppIcons.more,
                      semanticLabel: 'Lainnya',
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                const SectionHeader(title: 'Avatar Inisial'),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    AppAvatar(name: 'Ayu Lestari'),
                    SizedBox(width: 12),
                    AppAvatar(name: 'Dimas'),
                    SizedBox(width: 12),
                    AppAvatar(name: 'Budi Santoso'),
                    SizedBox(width: 12),
                    AppAvatar(name: 'Tim Desain', isGroup: true),
                  ],
                ),
                const SizedBox(height: 24),

                const SectionHeader(title: 'Penanda Belum Dibaca'),
                const SizedBox(height: 12),
                const Row(
                  children: [
                    UnreadBadge(count: 1),
                    SizedBox(width: 12),
                    UnreadBadge(count: 12),
                    SizedBox(width: 12),
                    UnreadBadge(count: 120),
                    SizedBox(width: 12),
                    UnreadDot(),
                  ],
                ),
                const SizedBox(height: 24),

                const SectionHeader(title: 'Item Daftar (Chat)'),
                const SizedBox(height: 12),
                const ListItemTile(
                  avatarName: 'Ayu Lestari',
                  title: 'Ayu Lestari',
                  subtitle: 'Besok kita lanjut desainnya ya',
                  time: '11.20',
                  unreadCount: 2,
                  isUnread: true,
                ),
                const SizedBox(height: 8),
                const ListItemTile(
                  avatarName: 'Budi Santoso',
                  title: 'Budi Santoso',
                  subtitle: 'Terima kasih!',
                  time: '09.05',
                ),
                const SizedBox(height: 24),

                const SectionHeader(title: 'Item Daftar (Notifikasi)'),
                const SizedBox(height: 12),
                ListItemTile(
                  icon: AppIcons.clock,
                  iconBackground: AppColors.reminderBg,
                  iconColor: AppColors.reminderIcon,
                  title: 'Pengingat: Ambil obat',
                  subtitle: 'Hari ini 07.00',
                  time: '07.00',
                  isUnread: true,
                  onTap: () {},
                ),
                const SizedBox(height: 8),
                ListItemTile(
                  icon: AppIcons.flag,
                  iconBackground: AppColors.milestoneBg,
                  iconColor: AppColors.milestoneIcon,
                  title: 'Milestone tercapai',
                  subtitle: 'Proyek Skripsi',
                  time: 'Kemarin',
                  unreadCount: 3,
                  onTap: () {},
                ),
                const SizedBox(height: 24),

                const SectionHeader(title: 'Kartu Kategori'),
                const SizedBox(height: 12),
                const CategoryCard(
                  category: TaskCategory.task,
                  title: 'Desain UI',
                  subtitle: 'Buat wireframe untuk halaman beranda',
                  label: 'Tugas',
                ),
                const SizedBox(height: 8),
                const CategoryCard(
                  category: TaskCategory.event,
                  title: 'Meeting Sprint',
                  subtitle: 'Diskusi backlog minggu ini',
                  label: 'Acara',
                ),
                const SizedBox(height: 8),
                const CategoryCard(
                  category: TaskCategory.reminder,
                  title: 'Ambil obat',
                  subtitle: 'Setiap pagi jam 07.00',
                  label: 'Pengingat',
                ),
                const SizedBox(height: 24),

                const SectionHeader(title: 'Keadaan Kosong'),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(32),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(AppRadius.card),
                    border: Border.all(color: AppColors.borderSoft),
                  ),
                  child: const EmptyState(
                    title: 'Belum ada data',
                    description: 'Tambahkan item untuk memulai',
                  ),
                ),
                const SizedBox(height: 24),

                SectionHeader(
                  title: 'Bottom Nav (${navOpen ? 'terbuka' : 'tertutup'})',
                  trailing: TextButton(
                    onPressed: () => setState(() => navOpen = !navOpen),
                    child: const Text('Ubah keadaan'),
                  ),
                ),
                const SizedBox(height: 12),
                AppBottomNav(
                  currentIndex: currentIndex,
                  isOpen: navOpen,
                  onTap: (index) {
                    if (index == 4) {
                      setState(() => navOpen = !navOpen);
                    } else {
                      setState(() => currentIndex = index);
                    }
                  },
                ),
                const SizedBox(height: 24),

                const SectionHeader(title: 'Data (Debug)'),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: _fillSampleData,
                        child: const Text('Isi data contoh'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _clearAllData,
                        child: const Text('Hapus semua data'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: _scheduleTestNotification,
                    child: const Text(AppStrings.notificationTestTitle),
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
