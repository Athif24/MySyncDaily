import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/core/theme/app_sizes.dart';
import 'package:sync_daily/core/theme/app_typography.dart';
import 'package:sync_daily/core/widgets/latar_layar.dart';
import 'package:sync_daily/features/notifications/domain/reminder_permissions.dart';
import 'package:sync_daily/features/settings/domain/app_settings.dart';
import 'package:sync_daily/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:flutter/services.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  String _version = '';
  bool _notif = true;
  bool _exact = true;
  ReminderPermissions? _perms;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final info = await PackageInfo.fromPlatform();
    if (!mounted) return;
    setState(() => _version = info.version);
    // best effort
    try {
      _perms = null;
    } catch (_) {}
    setState(() {});
  }

  Future<void> _openRepo() async {
    const url = 'https://github.com/Athif24/MySyncDaily';
    final uri = Uri.parse(url);
    try {
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!ok && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.settingsOpenFailed)),
        );
        await Clipboard.setData(const ClipboardData(text: url));
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text(AppStrings.settingsCopied)),
          );
        }
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text(AppStrings.settingsOpenFailed)),
      );
      await Clipboard.setData(const ClipboardData(text: url));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text(AppStrings.settingsCopied)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final s = state.settings;
        return LayarLatar(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(AppSizes.cardPadding + 4),
                child: Row(
                  children: [
                    IconButton(
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
                    Text(AppStrings.settingsTitle, style: AppTypography.textTheme.titleLarge),
                  ],
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(AppSizes.cardPadding + 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(AppStrings.settingsReminderDefaults, style: AppTypography.textTheme.titleMedium),
                      const SizedBox(height: AppSizes.itemSpacing),
                      Text(AppStrings.settingsHelpNote, style: AppTypography.textTheme.bodySmall),
                      const SizedBox(height: AppSizes.itemSpacing),
                      _AllDayRow(settings: s),
                      const SizedBox(height: AppSizes.itemSpacing),
                      Text(AppStrings.settingsForNewOnly, style: AppTypography.textTheme.bodySmall),
                      const Divider(),
                      Text(AppStrings.settingsPermissions, style: AppTypography.textTheme.titleMedium),
                      const SizedBox(height: AppSizes.itemSpacing),
                      ListTile(
                        title: const Text(AppStrings.settingsNotifications),
                        trailing: Text(_notif ? AppStrings.settingsActive : AppStrings.settingsNotActive),
                      ),
                      ListTile(
                        title: const Text(AppStrings.settingsExactAlarm),
                        trailing: Text(_exact ? AppStrings.settingsActive : AppStrings.settingsNotActive),
                      ),
                      const Divider(),
                      Text(AppStrings.settingsGuide, style: AppTypography.textTheme.titleMedium),
                      const SizedBox(height: AppSizes.itemSpacing),
                      Text(AppStrings.settingsGuideLabel, style: AppTypography.textTheme.bodySmall),
                      const SizedBox(height: AppSizes.itemSpacing),
                      Text(AppStrings.oemGuideIntro, style: AppTypography.textTheme.bodySmall),
                      ...AppStrings.oemGuideSteps.map((e) => Padding(
                            padding: const EdgeInsets.symmetric(vertical: 2),
                            child: Text('• $e', style: AppTypography.textTheme.bodySmall),
                          )),
                      const Divider(),
                      Text(AppStrings.settingsAbout, style: AppTypography.textTheme.titleMedium),
                      const SizedBox(height: AppSizes.itemSpacing),
                      ListTile(
                        title: const Text(AppStrings.settingsAppName),
                        trailing: Text(_version.isEmpty ? '-' : _version),
                      ),
                      ListTile(
                        title: const Text(AppStrings.settingsRepository),
                        subtitle: const Text('https://github.com/Athif24/MySyncDaily'),
                        onTap: _openRepo,
                      ),
                      const SizedBox(height: AppSizes.itemSpacing),
                      Text(AppStrings.settingsDndNote, style: AppTypography.textTheme.bodySmall),
                      Text(AppStrings.settingsThemeNote, style: AppTypography.textTheme.bodySmall),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
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
