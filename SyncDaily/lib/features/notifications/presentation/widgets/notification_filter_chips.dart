import 'package:flutter/material.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/core/theme/app_sizes.dart';
import 'package:sync_daily/core/widgets/app_chip.dart';
import 'package:sync_daily/features/notifications/domain/notification_kind.dart';

/// Deretan chip jenis notifikasi.
///
/// [value] `null` berarti chip pertama aktif: "Semua". Chip "Pesan" belum
/// ditampilkan sampai fitur chat ada (lihat docs/DESIGN.md butir 6).
class NotificationFilterChips extends StatelessWidget {
  final NotificationKind? value;
  final ValueChanged<NotificationKind?> onChanged;

  const NotificationFilterChips({
    super.key,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: AppSizes.itemSpacing,
      runSpacing: AppSizes.itemSpacing,
      children: [
        AppChip(
          label: AppStrings.notificationKindAll,
          isActive: value == null,
          onTap: () => onChanged(null),
        ),
        for (final kind in NotificationKind.values)
          AppChip(
            label: kind.label,
            isActive: value == kind,
            onTap: () => onChanged(kind),
          ),
      ],
    );
  }
}
