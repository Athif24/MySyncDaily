import 'package:flutter_test/flutter_test.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/core/utils/id_date.dart';
import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';
import 'package:sync_daily/features/notifications/domain/notification_day_group.dart';

void main() {
  setUpAll(() async {
    await IdDate.ensureInitialized();
  });

  AppNotification entry(String id, DateTime createdAt) => AppNotification(
        id: id,
        type: NotificationType.reminder,
        title: id,
        createdAt: createdAt,
        updatedAt: createdAt,
      );

  test('dikelompokkan per hari lokal, hari terbaru lebih dulu', () {
    final today = DateTime(2026, 10, 15);
    final groups = groupNotificationsByDay([
      entry('a', DateTime(2026, 10, 15, 9)),
      entry('b', DateTime(2026, 10, 15, 7)),
      entry('c', DateTime(2026, 10, 14, 20)),
    ]);

    expect(groups, hasLength(2));
    expect(groups[0].day, DateTime(2026, 10, 15));
    expect(groups[1].day, DateTime(2026, 10, 14));
    // Di dalam satu hari, entri terbaru lebih dulu.
    expect(
      groups[0].entries.map((e) => e.id).toList(),
      ['a', 'b'],
    );

    expect(notificationDayLabel(groups[0].day, today),
        AppStrings.notificationGroupToday);
    expect(notificationDayLabel(groups[1].day, today),
        AppStrings.notificationGroupYesterday);
  });

  test('hari yang lebih tua memakai tanggal id_ID', () {
    final today = DateTime(2026, 10, 15);
    final older = DateTime(2026, 10, 12);

    expect(
      notificationDayLabel(older, today),
      IdDate.dayMonth(older),
    );
  });

  test('tahun berbeda memakai tanggal lengkap', () {
    final today = DateTime(2026, 10, 15);
    final lastYear = DateTime(2025, 12, 31);

    expect(
      notificationDayLabel(lastYear, today),
      IdDate.full(lastYear),
    );
  });
}
