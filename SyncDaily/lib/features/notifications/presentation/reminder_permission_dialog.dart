import 'package:flutter/material.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/features/notifications/domain/reminder_permissions.dart';

/// Menampilkan penjelasan izin setelah pengguna menyimpan item berpengingat
/// tetapi izin notifikasi/alarm tepat waktu belum aktif.
///
/// Panduan OEM ditampilkan DI SINI (dan juga lewat tautan di form tugas), sesuai
/// keputusan F8a.
Future<void> showReminderPermissionDialog(
  BuildContext context, {
  required ReminderPermissions permissions,
  required bool notificationsEnabled,
  required bool exactAlarmsEnabled,
}) async {
  final title =
      notificationsEnabled ? AppStrings.permissionExactTitle : AppStrings.permissionTitle;
  final body =
      notificationsEnabled ? AppStrings.permissionExactBody : AppStrings.permissionBody;

  final openSettings = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(body),
          const SizedBox(height: 12),
          const Text(AppStrings.permissionOemNote),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(false),
          child: const Text(AppStrings.permissionLater),
        ),
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(true),
          child: const Text(AppStrings.permissionOpenSettings),
        ),
      ],
    ),
  );

  if (openSettings != true) {
    return;
  }
  if (!notificationsEnabled) {
    await permissions.openSettings();
  } else if (!exactAlarmsEnabled) {
    await permissions.requestExactAlarmsPermission();
  }
}

/// Menampilkan panduan agar pengingat tidak terlewat (pembatasan OEM).
Future<void> showReminderOemGuideDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(AppStrings.oemGuideTitle),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(AppStrings.oemGuideIntro),
            const SizedBox(height: 12),
            for (final step in AppStrings.oemGuideSteps)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text('• $step'),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: const Text(AppStrings.oemGuideDismiss),
        ),
      ],
    ),
  );
}
