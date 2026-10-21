import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Lokasi rute halaman Notifikasi (di luar shell, tampil penuh).
const String notificationsRoutePath = '/notifications';

/// Membuka halaman Notifikasi tanpa menumpuk.
///
/// Bila halaman Notifikasi sudah menjadi layar teratas, pembukaan dilewati
/// supaya ketukan ganda pada lonceng tidak menambah tumpukan rute.
void openNotificationsPage(BuildContext context) {
  final router = GoRouter.of(context);
  if (router.routerDelegate.currentConfiguration.uri.path ==
      notificationsRoutePath) {
    return;
  }
  router.push(notificationsRoutePath);
}
