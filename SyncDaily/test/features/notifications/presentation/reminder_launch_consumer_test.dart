import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sync_daily/features/notifications/domain/reminder_notification.dart';
import 'package:sync_daily/features/notifications/presentation/reminder_launch_consumer.dart';
import 'package:sync_daily/features/notifications/presentation/reminder_response_handler.dart';

import '../../../helpers/fake_reminder_scheduler.dart';

class MockReminderResponseHandler extends Mock
    implements ReminderResponseHandler {}

void main() {
  late FakeReminderScheduler scheduler;
  late MockReminderResponseHandler handler;

  setUpAll(() {
    registerFallbackValue(const ReminderResponse(taskId: 'x'));
  });

  setUp(() {
    scheduler = FakeReminderScheduler();
    handler = MockReminderResponseHandler();
    when(() => handler.handle(any())).thenAnswer((_) async {});
  });

  test('respons peluncuran dibaca dan ditangani satu kali saja', () async {
    scheduler.launchResponseResult =
        const ReminderResponse(notificationId: 5, taskId: 't1');
    final consumer = ReminderLaunchConsumer(
      scheduler: scheduler,
      handler: handler,
    );

    // Panggilan berulang meniru pembacaan saat aplikasi dilanjutkan (resume).
    await consumer.consume();
    await consumer.consume();
    await consumer.consume();

    expect(scheduler.launchResponseCalls, 1);
    verify(() => handler.handle(any())).called(1);
  });

  test('tanpa notifikasi pembuka, tidak ada yang ditangani', () async {
    await ReminderLaunchConsumer(
      scheduler: scheduler,
      handler: handler,
    ).consume();

    expect(scheduler.launchResponseCalls, 1);
    verifyNever(() => handler.handle(any()));
  });
}
