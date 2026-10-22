import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sync_daily/core/di/injection.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/core/theme/app_sizes.dart';
import 'package:sync_daily/core/theme/app_typography.dart';
import 'package:sync_daily/core/widgets/latar_layar.dart';
import 'package:sync_daily/features/notifications/domain/reminder_permissions.dart';
import 'package:sync_daily/features/settings/domain/app_settings.dart';
import 'package:sync_daily/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:url_launcher/url_launcher.dart';

/// Keadaan status satu izin (notifikasi atau alarm tepat waktu).
enum _PermissionStatus {
  /// Sedang diperiksa; status belum diketahui sehingga tidak boleh ditampilkan
  /// sebagai "Aktif".
  checking,

  /// Izin aktif.
  active,

  /// Izin tidak aktif; pengguna bisa membuka pengaturan sistem.
  inactive,

  /// Pemeriksaan gagal; status tidak diketahui dan tidak boleh dikira aktif.
  failed,
}

/// Layar Pengaturan (F9a tahap 2B).
///
/// Isi: jam bunyi item seharian, status izin (notifikasi & alarm tepat waktu),
/// panduan OEM, dan tentang aplikasi.
///
/// Status izin dibaca dari [ReminderPermissions] yang terdaftar di `get_it`
/// (bisa diganti tiruan saat pengujian) dan disegarkan ulang saat aplikasi
/// kembali aktif, karena pengguna bisa mengubah izin lewat pengaturan sistem.
class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage>
    with WidgetsBindingObserver {
  static const String _repositoryUrl = 'https://github.com/Athif24/MySyncDaily';

  String _version = '';
  _PermissionStatus _notificationStatus = _PermissionStatus.checking;
  _PermissionStatus _exactAlarmStatus = _PermissionStatus.checking;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_loadVersion());
    unawaited(_refreshPermissions());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Izin bisa diubah di pengaturan sistem saat aplikasi tidak tampil.
      unawaited(_refreshPermissions());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      if (!mounted) {
        return;
      }
      setState(() => _version = info.version);
    } catch (_) {
      // Versi tidak terbaca: biarkan kosong (tampil sebagai "-").
    }
  }

  /// Memeriksa ulang status izin. Setiap izin dicek terpisah supaya satu
  /// pemeriksaan yang gagal tidak menutupi hasil pemeriksaan yang lain.
  Future<void> _refreshPermissions() async {
    final ReminderPermissions permissions;
    try {
      permissions = getIt<ReminderPermissions>();
    } catch (_) {
      _setNotificationStatus(_PermissionStatus.failed);
      _setExactAlarmStatus(_PermissionStatus.failed);
      return;
    }
    await Future.wait([
      _refreshNotificationStatus(permissions),
      _refreshExactAlarmStatus(permissions),
    ]);
  }

  Future<void> _refreshNotificationStatus(
    ReminderPermissions permissions,
  ) async {
    final bool enabled;
    try {
      enabled = await permissions.notificationsEnabled();
    } catch (_) {
      _setNotificationStatus(_PermissionStatus.failed);
      return;
    }
    _setNotificationStatus(
      enabled ? _PermissionStatus.active : _PermissionStatus.inactive,
    );
  }

  Future<void> _refreshExactAlarmStatus(ReminderPermissions permissions) async {
    final bool enabled;
    try {
      enabled = await permissions.canScheduleExactAlarms();
    } catch (_) {
      _setExactAlarmStatus(_PermissionStatus.failed);
      return;
    }
    _setExactAlarmStatus(
      enabled ? _PermissionStatus.active : _PermissionStatus.inactive,
    );
  }

  void _setNotificationStatus(_PermissionStatus status) {
    if (!mounted) {
      return;
    }
    setState(() => _notificationStatus = status);
  }

  void _setExactAlarmStatus(_PermissionStatus status) {
    if (!mounted) {
      return;
    }
    setState(() => _exactAlarmStatus = status);
  }

  /// Membuka pengaturan sistem aplikasi (jalur yang sama dengan form tugas).
  Future<void> _openSystemSettings() async {
    try {
      await getIt<ReminderPermissions>().openSettings();
    } catch (_) {
      // Gagal membuka pengaturan sistem tidak boleh menghentikan aplikasi.
    }
  }

  /// Membuka layar permintaan alarm tepat waktu (Android 12+).
  Future<void> _requestExactAlarms() async {
    try {
      await getIt<ReminderPermissions>().requestExactAlarmsPermission();
    } catch (_) {
      // Gagal membuka permintaan izin tidak boleh menghentikan aplikasi.
    }
  }

  Future<void> _openRepo() async {
    final uri = Uri.parse(_repositoryUrl);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) {
        return;
      }
    } catch (_) {
      // Ditangani di bawah: tautan disalin supaya pengguna tetap bisa
      // membukanya secara manual.
    }
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.settingsOpenFailed)),
    );
    await Clipboard.setData(const ClipboardData(text: _repositoryUrl));
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text(AppStrings.settingsCopied)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final cubit = getIt<SettingsCubit>();
    return BlocProvider.value(
      value: cubit,
      child: BlocListener<SettingsCubit, SettingsState>(
        listenWhen: (previous, current) =>
            current.errorMessage != null &&
            previous.errorMessage != current.errorMessage,
        listener: (context, state) {
          final message = state.errorMessage;
          if (message == null) {
            return;
          }
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(message)),
          );
          cubit.clearError();
        },
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            final s = state.settings;
            return Scaffold(
              backgroundColor: Colors.transparent,
              body: LayarLatar(
                child: SafeArea(
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.all(AppSizes.cardPadding + 4),
                        child: Row(
                          children: [
                            IconButton(
                              tooltip: AppStrings.back,
                              onPressed: () {
                                if (Navigator.of(context).canPop()) {
                                  Navigator.of(context).pop();
                                } else {
                                  Navigator.of(context).maybePop();
                                }
                              },
                              icon: const Icon(Icons.arrow_back),
                            ),
                            const SizedBox(width: AppSizes.itemSpacing),
                            Text(
                              AppStrings.settingsTitle,
                              style: AppTypography.textTheme.titleLarge,
                            ),
                          ],
                        ),
                      ),
                      Expanded(
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(AppSizes.cardPadding + 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.settingsReminderDefaults,
                                style: AppTypography.textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSizes.itemSpacing),
                              Text(
                                AppStrings.settingsHelpNote,
                                style: AppTypography.textTheme.bodySmall,
                              ),
                              const SizedBox(height: AppSizes.itemSpacing),
                              _AllDayRow(settings: s),
                              const SizedBox(height: AppSizes.itemSpacing),
                              Text(
                                AppStrings.settingsForNewOnly,
                                style: AppTypography.textTheme.bodySmall,
                              ),
                              const Divider(),
                              Text(
                                AppStrings.settingsPermissions,
                                style: AppTypography.textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSizes.itemSpacing),
                              _PermissionRow(
                                key: const Key('permission-notifications'),
                                label: AppStrings.settingsNotifications,
                                status: _notificationStatus,
                                actionLabel: AppStrings.settingsOpenSystem,
                                onAction: _openSystemSettings,
                              ),
                              _PermissionRow(
                                key: const Key('permission-exact-alarm'),
                                label: AppStrings.settingsExactAlarm,
                                status: _exactAlarmStatus,
                                actionLabel: AppStrings.settingsSetExact,
                                onAction: _requestExactAlarms,
                              ),
                              const Divider(),
                              Text(
                                AppStrings.settingsGuide,
                                style: AppTypography.textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSizes.itemSpacing),
                              Text(
                                AppStrings.settingsGuideLabel,
                                style: AppTypography.textTheme.bodySmall,
                              ),
                              const SizedBox(height: AppSizes.itemSpacing),
                              Text(
                                AppStrings.oemGuideIntro,
                                style: AppTypography.textTheme.bodySmall,
                              ),
                              ...AppStrings.oemGuideSteps.map(
                                (e) => Padding(
                                  padding: const EdgeInsets.symmetric(vertical: 2),
                                  child: Text(
                                    '• $e',
                                    style: AppTypography.textTheme.bodySmall,
                                  ),
                                ),
                              ),
                              const Divider(),
                              Text(
                                AppStrings.settingsAbout,
                                style: AppTypography.textTheme.titleMedium,
                              ),
                              const SizedBox(height: AppSizes.itemSpacing),
                              ListTile(
                                title: const Text(AppStrings.settingsAppName),
                                trailing: Text(_version.isEmpty ? '-' : _version),
                              ),
                              ListTile(
                                title: const Text(AppStrings.settingsRepository),
                                subtitle: const Text(_repositoryUrl),
                                onTap: _openRepo,
                              ),
                              const SizedBox(height: AppSizes.itemSpacing),
                              Text(
                                AppStrings.settingsDndNote,
                                style: AppTypography.textTheme.bodySmall,
                              ),
                              Text(
                                AppStrings.settingsThemeNote,
                                style: AppTypography.textTheme.bodySmall,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

/// Baris status satu izin.
///
/// Tingginya tetap sama di semua keadaan (sedang diperiksa, aktif, tidak
/// aktif, gagal): judul dan status punya baris masing-masing, dan tempat
/// tombol selalu dialokasikan. Jadi tidak ada lompatan tata letak ketika hasil
/// pemeriksaan baru saja muncul.
class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    super.key,
    required this.label,
    required this.status,
    required this.actionLabel,
    required this.onAction,
  });

  final String label;
  final _PermissionStatus status;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSizes.itemSpacing / 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTypography.textTheme.titleSmall),
          Text(
            _statusText(),
            style: AppTypography.textTheme.bodySmall,
          ),
          SizedBox(
            height: AppSizes.minTouchTarget,
            child: Align(
              alignment: Alignment.centerLeft,
              child: status == _PermissionStatus.inactive
                  ? TextButton(
                      onPressed: onAction,
                      style: TextButton.styleFrom(
                        minimumSize: const Size(0, AppSizes.minTouchTarget),
                        padding: EdgeInsets.zero,
                        alignment: Alignment.centerLeft,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: Text(actionLabel),
                    )
                  : const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }

  String _statusText() {
    switch (status) {
      case _PermissionStatus.checking:
        return AppStrings.settingsChecking;
      case _PermissionStatus.active:
        return AppStrings.settingsActive;
      case _PermissionStatus.inactive:
        return AppStrings.settingsNotActive;
      case _PermissionStatus.failed:
        return AppStrings.settingsCheckFailed;
    }
  }
}

class _AllDayRow extends StatelessWidget {
  const _AllDayRow({required this.settings});

  final AppSettings settings;

  @override
  Widget build(BuildContext context) {
    final minutes = settings.allDayReminderHourMinutes.clamp(0, 1439);
    final h = minutes ~/ 60;
    final m = minutes % 60;
    final time = TimeOfDay(hour: h, minute: m);
    return ListTile(
      title: const Text(AppStrings.settingsAllDayTime),
      trailing: Text(time.format(context)),
      onTap: () async {
        final picked = await showTimePicker(context: context, initialTime: time);
        if (picked == null) return;
        final total = picked.hour * 60 + picked.minute;
        if (!context.mounted) return;
        await context.read<SettingsCubit>().updateAllDayHourMinutes(total);
      },
    );
  }
}
