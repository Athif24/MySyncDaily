import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:sync_daily/features/notifications/domain/reminder_permissions.dart';

/// Implementasi [ReminderPermissions] di atas `flutter_local_notifications`
/// (izin notifikasi & alarm tepat waktu) dan `permission_handler` (membuka
/// pengaturan aplikasi).
class ReminderPermissionsImpl implements ReminderPermissions {
  final FlutterLocalNotificationsPlugin _plugin;

  ReminderPermissionsImpl({FlutterLocalNotificationsPlugin? plugin})
      : _plugin = plugin ?? FlutterLocalNotificationsPlugin();

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  @override
  Future<bool> notificationsEnabled() async {
    // Bukan Android (mis. saat pengujian) => anggap aktif.
    return await _android?.areNotificationsEnabled() ?? true;
  }

  @override
  Future<bool> ensureNotificationPermission() async {
    final android = _android;
    if (android == null) {
      return true;
    }
    if (await android.areNotificationsEnabled() ?? false) {
      return true;
    }
    return await android.requestNotificationsPermission() ?? false;
  }

  @override
  Future<bool> canScheduleExactAlarms() async {
    // Null berarti perangkat tidak membatasi alarm tepat waktu (Android < 12).
    return await _android?.canScheduleExactNotifications() ?? true;
  }

  @override
  Future<void> requestExactAlarmsPermission() async {
    await _android?.requestExactAlarmsPermission();
  }

  @override
  Future<void> openSettings() => openAppSettings();
}
