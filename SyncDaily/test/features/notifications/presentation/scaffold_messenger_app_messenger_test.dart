import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/features/notifications/presentation/scaffold_messenger_app_messenger.dart';

void main() {
  testWidgets('menampilkan snackbar di layar yang sedang tampil',
      (tester) async {
    await tester.pumpWidget(MaterialApp(
      scaffoldMessengerKey: appScaffoldMessengerKey,
      home: const Scaffold(body: SizedBox.shrink()),
    ));

    const messenger = ScaffoldMessengerAppMessenger();
    messenger.showSnackBar(AppStrings.notificationDoneConfirmation);
    await tester.pump();

    expect(find.text(AppStrings.notificationDoneConfirmation), findsOneWidget);
  });
}
