import 'package:flutter/material.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/core/theme/app_colors.dart';
import 'package:sync_daily/core/theme/app_sizes.dart';
import 'package:sync_daily/core/theme/app_theme.dart';
import 'package:sync_daily/core/theme/app_typography.dart';
import 'package:sync_daily/core/widgets/list_item_tile.dart';
import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_id.dart';
import 'package:sync_daily/features/notifications/presentation/widgets/notification_labels.dart';
import 'package:sync_daily/features/tasks/presentation/widgets/task_date_label.dart'
    show clockLabel;

/// Kartu satu entri riwayat notifikasi.
///
/// Tombol aksi "Selesai"/"Tunda 10 menit" hanya tampil pada entri yang berasal
/// dari pengingat DAN masih belum dibaca; begitu entri ditandai dibaca (ketukan
/// atau aksi), tombolnya hilang.
class NotificationItemTile extends StatelessWidget {
  final AppNotification entry;
  final VoidCallback? onTap;
  final VoidCallback? onDone;
  final VoidCallback? onSnooze;

  const NotificationItemTile({
    super.key,
    required this.entry,
    this.onTap,
    this.onDone,
    this.onSnooze,
  });

  bool get _isReminderOrigin =>
      entry.entityType == notificationTaskEntityType && entry.entityId != null;

  bool get _showActions => _isReminderOrigin && !entry.isRead;

  @override
  Widget build(BuildContext context) {
    final colors = context.categoryColors;
    final category = notificationCategoryFor(entry.type);

    return ListItemTile(
      icon: notificationIconFor(entry.type),
      iconBackground: colors.backgroundFor(category),
      iconColor: colors.iconFor(category),
      title: entry.title,
      subtitle: entry.body,
      time: clockLabel(entry.createdAt.toLocal()),
      isUnread: !entry.isRead,
      bottomBar: _showActions
          ? _ActionBar(onDone: onDone, onSnooze: onSnooze)
          : null,
      onTap: onTap,
    );
  }
}

/// Baris aksi di dasar kartu (di luar area ketuk utama).
class _ActionBar extends StatelessWidget {
  final VoidCallback? onDone;
  final VoidCallback? onSnooze;

  const _ActionBar({this.onDone, this.onSnooze});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.borderSoft)),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextButton(
              onPressed: onDone,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppSizes.minTouchTarget),
              ),
              child: Text(
                AppStrings.notificationActionDone,
                style: AppTypography.textTheme.labelLarge,
              ),
            ),
          ),
          Expanded(
            child: TextButton(
              onPressed: onSnooze,
              style: TextButton.styleFrom(
                minimumSize: const Size(0, AppSizes.minTouchTarget),
              ),
              child: Text(
                AppStrings.notificationActionSnooze,
                style: AppTypography.textTheme.labelLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
