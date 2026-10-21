import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sync_daily/core/di/injection.dart';
import 'package:sync_daily/core/router/app_router.dart';
import 'package:sync_daily/core/theme/app_theme.dart';
import 'package:sync_daily/core/utils/id_date.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_reconciler.dart';
import 'package:sync_daily/features/notifications/domain/reminder_notification.dart';
import 'package:sync_daily/features/notifications/domain/reminder_synchronizer.dart';
import 'package:sync_daily/features/notifications/presentation/reminder_launch_consumer.dart';
import 'package:sync_daily/features/notifications/presentation/reminder_response_handler.dart';
import 'package:sync_daily/features/notifications/presentation/scaffold_messenger_app_messenger.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await IdDate.ensureInitialized();
  await configureDependencies();
  await getIt<ReminderScheduler>().initialize(
    onResponse: (response) =>
        unawaited(getIt<ReminderResponseHandler>().handle(response)),
  );
  runApp(const SyncDailyApp());
}

class SyncDailyApp extends StatefulWidget {
  const SyncDailyApp({super.key});

  @override
  State<SyncDailyApp> createState() => _SyncDailyAppState();
}

class _SyncDailyAppState extends State<SyncDailyApp>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Sinkronisasi dijalankan SETELAH frame pertama agar tidak menahan
    // tampilan, dan dibatasi frekuensinya oleh ReminderSynchronizer.
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncReminders());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_syncReminders());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _syncReminders() async {
    if (!getIt.isRegistered<ReminderScheduler>()) {
      return;
    }
    // 1) Susun riwayat dari pengingat yang sudah berbunyi. HARUS selesai lebih
    //    dulu (dan tidak boleh berjalan bersamaan) supaya entri sudah terbentuk
    //    saat respons peluncuran ditandai dibaca; kalau tidak, penandaan bisa
    //    hilang dan entri tetap tampak belum dibaca. Reconcile menunggu proses
    //    yang sedang berjalan bila ada (lihat NotificationHistoryReconciler).
    await getIt<NotificationHistoryReconciler>().reconcile();
    // 2) Membaca notifikasi pembuka aplikasi SATU kali saja; panggilan
    //    berikutnya (mis. saat resume) tidak memproses ulang ketukan lama.
    await getIt<ReminderLaunchConsumer>().consume();
    await getIt<ReminderSynchronizer>().resyncAll();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'SyncDaily',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: appScaffoldMessengerKey,
      theme: AppTheme.light(),
      routerConfig: AppRouter.router,
    );
  }
}
