import 'package:flutter/material.dart';
import 'package:sync_daily/features/notifications/domain/app_messenger.dart';

/// Kunci messenger global. Dipasang di `MaterialApp.router` supaya handler
/// respons notifikasi bisa menampilkan snackbar di layar yang sedang tampil,
/// di luar pohon widget.
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

/// [AppMessenger] yang menampilkan snackbar lewat [appScaffoldMessengerKey].
class ScaffoldMessengerAppMessenger implements AppMessenger {
  const ScaffoldMessengerAppMessenger();

  @override
  void showSnackBar(String message) {
    appScaffoldMessengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }
}
