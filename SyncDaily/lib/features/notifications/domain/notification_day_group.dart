import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/core/utils/id_date.dart';
import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';

/// Satu kelompok entri notifikasi dalam satu hari (waktu lokal).
class NotificationDayGroup {
  final DateTime day;
  final List<AppNotification> entries;

  const NotificationDayGroup({required this.day, required this.entries});
}

/// Mengelompokkan [entries] per hari lokal.
///
/// Hari terbaru lebih dulu; di dalam satu hari entri terbaru lebih dulu.
List<NotificationDayGroup> groupNotificationsByDay(
  List<AppNotification> entries,
) {
  final byDay = <DateTime, List<AppNotification>>{};
  for (final entry in entries) {
    final local = entry.createdAt.toLocal();
    final day = DateTime(local.year, local.month, local.day);
    byDay.putIfAbsent(day, () => <AppNotification>[]).add(entry);
  }

  final days = byDay.keys.toList()..sort((a, b) => b.compareTo(a));
  return [
    for (final day in days)
      NotificationDayGroup(
        day: day,
        entries: byDay[day]!
          ..sort((a, b) => b.createdAt.compareTo(a.createdAt)),
      ),
  ];
}

/// Label kepala kelompok: "Hari Ini", "Kemarin", atau tanggal `id_ID`.
String notificationDayLabel(DateTime day, DateTime today) {
  final todayOnly = DateTime(today.year, today.month, today.day);
  final diff = todayOnly.difference(day).inDays;
  if (diff == 0) {
    return AppStrings.notificationGroupToday;
  }
  if (diff == 1) {
    return AppStrings.notificationGroupYesterday;
  }
  return day.year == todayOnly.year
      ? IdDate.dayMonth(day)
      : IdDate.full(day);
}
