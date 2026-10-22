import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:sync_daily/core/di/injection.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/core/theme/app_theme.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_reconciler.dart';
import 'package:sync_daily/features/notifications/domain/reminder_permissions.dart';
import 'package:sync_daily/features/notifications/domain/reminder_synchronizer.dart';
import 'package:sync_daily/features/settings/domain/app_settings.dart';
import 'package:sync_daily/features/settings/domain/app_settings_repository.dart';
import 'package:sync_daily/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:sync_daily/features/settings/presentation/pages/settings_page.dart';
import 'package:url_launcher_platform_interface/link.dart';
import 'package:url_launcher_platform_interface/url_launcher_platform_interface.dart';

import '../../../../helpers/fake_reminder_scheduler.dart';
import '../../../../helpers/reset_app_state.dart';
import '../../../../helpers/test_repositories.dart';

/// Repository pengaturan palsu: nilai bisa diubah dan bisa gagal saat
/// menyimpan.
class _FakeSettingsRepository implements AppSettingsRepository {
  _FakeSettingsRepository([AppSettings? initial])
      : _settings = initial ?? const AppSettings();

  AppSettings _settings;
  final _controller = StreamController<AppSettings>.broadcast();

  /// Bila diisi, `update` melempar galat ini.
  Object? error;

  @override
  AppSettings get settings => _settings;

  @override
  Stream<AppSettings> get stream => _controller.stream;

  @override
  Future<void> init() async {}

  @override
  Future<void> update(AppSettings settings) async {
    final failure = error;
    if (failure != null) {
      throw failure;
    }
    _settings = settings;
    _controller.add(settings);
  }

  @override
  Future<void> reset() async {
    _settings = const AppSettings();
    _controller.add(_settings);
  }
}

/// Rekonsiliasi dan sinkronisasi palsu: tidak menyentuh database maupun
/// plugin notifikasi.
class _NoopReconciler extends NotificationHistoryReconciler {
  _NoopReconciler()
      : super(
          taskRepository: MockTaskRepository(),
          notificationRepository: MockNotificationRepository(),
        );

  @override
  Future<void> reconcile({bool force = false}) async {}
}

class _NoopSynchronizer extends ReminderSynchronizer {
  _NoopSynchronizer()
      : super(
          taskRepository: MockTaskRepository(),
          scheduler: FakeReminderScheduler(),
        );

  @override
  Future<void> resyncAll({bool force = false}) async {}
}

/// Izin palsu: hasil pemeriksaan bisa diubah, dan pemeriksaan bisa gagal.
class _FakePermissions implements ReminderPermissions {
  _FakePermissions();

  bool notificationsEnabledResult = true;
  bool exactAlarmsResult = true;

  /// Bila diisi, pemeriksaan tersebut melempar galat.
  Object? notificationsError;
  Object? exactAlarmsError;

  int notificationsChecks = 0;
  int exactAlarmsChecks = 0;
  int openSettingsCalls = 0;
  int requestExactAlarmsCalls = 0;

  @override
  Future<bool> notificationsEnabled() async {
    notificationsChecks++;
    final failure = notificationsError;
    if (failure != null) {
      throw failure;
    }
    return notificationsEnabledResult;
  }

  @override
  Future<bool> ensureNotificationPermission() async =>
      notificationsEnabledResult;

  @override
  Future<bool> canScheduleExactAlarms() async {
    exactAlarmsChecks++;
    final failure = exactAlarmsError;
    if (failure != null) {
      throw failure;
    }
    return exactAlarmsResult;
  }

  @override
  Future<void> requestExactAlarmsPermission() async {
    requestExactAlarmsCalls++;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCalls++;
  }
}

/// Izin yang pemeriksaanNYA belum selesai (meniru keadaan "sedang memeriksa").
class _PendingPermissions implements ReminderPermissions {
  final notifications = Completer<bool>();
  final exactAlarms = Completer<bool>();

  int openSettingsCalls = 0;
  int requestExactAlarmsCalls = 0;

  @override
  Future<bool> notificationsEnabled() => notifications.future;

  @override
  Future<bool> ensureNotificationPermission() => notifications.future;

  @override
  Future<bool> canScheduleExactAlarms() => exactAlarms.future;

  @override
  Future<void> requestExactAlarmsPermission() async {
    requestExactAlarmsCalls++;
  }

  @override
  Future<void> openSettings() async {
    openSettingsCalls++;
  }
}

/// Peluncur tautan palsu (menggantikan UrlLauncherPlatform).
class _FakeUrlLauncher extends UrlLauncherPlatform {
  _FakeUrlLauncher({this.result = true});

  final bool result;

  int launchCalls = 0;

  @override
  LinkDelegate? get linkDelegate => null;

  @override
  Future<bool> launchUrl(String url, LaunchOptions options) async {
    launchCalls++;
    return result;
  }

  @override
  Future<bool> canLaunch(String url) async => result;
}

String _formatTime(int hour, int minute) {
  return const DefaultMaterialLocalizations().formatTimeOfDay(
    TimeOfDay(hour: hour, minute: minute),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final originalLauncher = UrlLauncherPlatform.instance;

  late _FakeSettingsRepository repository;
  late _FakePermissions permissions;
  SettingsCubit? cubit;
  String? clipboardText;

  setUp(() async {
    await resetGlobalTestState();

    repository = _FakeSettingsRepository();
    permissions = _FakePermissions();

    getIt.registerSingleton<AppSettingsRepository>(repository);
    getIt.registerSingleton<ReminderPermissions>(permissions);

    clipboardText = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        final arguments = call.arguments;
        if (arguments is Map) {
          clipboardText = arguments['text'] as String?;
        }
      }
      return null;
    });
  });

  tearDown(() async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
    UrlLauncherPlatform.instance = originalLauncher;
    await cubit?.close();
    await getIt.reset();
  });

  Future<void> pumpSettings(
    WidgetTester tester, {
    Size size = const Size(400, 800),
    double textScale = 1.0,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    // Kubit dibuat di dalam badan tes (bukan di setUp): `flutter_test`
    // menjalankan badan tes di zona fake-async, sedangkan setUp berjalan di
    // zona biasa. Kalau kubit dibuat di setUp, callback stream-nya berjalan di
    // zona setUp dan perubahan state baru sampai ke UI setelah tes selesai.
    final dibuat = SettingsCubit(
      repository: repository,
      reconciler: _NoopReconciler(),
      synchronizer: _NoopSynchronizer(),
    );
    cubit = dibuat;
    getIt.registerSingleton<SettingsCubit>(dibuat);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
          ),
          child: child!,
        ),
        home: const SettingsPage(),
      ),
    );
  }

  group('Status izin di layar Pengaturan', () {
    testWidgets('saat izin sedang diperiksa, status belum menampilkan Aktif',
        (tester) async {
      final pending = _PendingPermissions();
      getIt.unregister<ReminderPermissions>();
      getIt.registerSingleton<ReminderPermissions>(pending);

      await pumpSettings(tester);
      await tester.pump();

      expect(find.text(AppStrings.settingsActive), findsNothing);
      expect(find.text(AppStrings.settingsChecking), findsNWidgets(2));
    });

    testWidgets('notifikasi dan alarm aktif menampilkan Aktif tanpa tombol',
        (tester) async {
      await pumpSettings(tester);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.settingsActive), findsNWidgets(2));
      expect(find.text(AppStrings.settingsNotActive), findsNothing);
      expect(find.text(AppStrings.settingsOpenSystem), findsNothing);
      expect(find.text(AppStrings.settingsSetExact), findsNothing);
    });

    testWidgets('notifikasi mati menampilkan tombol buka pengaturan sistem',
        (tester) async {
      permissions.notificationsEnabledResult = false;

      await pumpSettings(tester);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.settingsNotActive), findsOneWidget);
      expect(find.text(AppStrings.settingsOpenSystem), findsOneWidget);

      await tester.tap(find.text(AppStrings.settingsOpenSystem));
      await tester.pumpAndSettle();

      expect(permissions.openSettingsCalls, 1);
    });

    testWidgets('alarm tidak bisa diatur menampilkan tombol atur alarm',
        (tester) async {
      permissions.exactAlarmsResult = false;

      await pumpSettings(tester);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.settingsNotActive), findsOneWidget);
      expect(find.text(AppStrings.settingsSetExact), findsOneWidget);

      await tester.tap(find.text(AppStrings.settingsSetExact));
      await tester.pumpAndSettle();

      expect(permissions.requestExactAlarmsCalls, 1);
    });

    testWidgets('pemeriksaan yang gagal menampilkan Tidak dapat diperiksa',
        (tester) async {
      permissions.notificationsError = StateError('gagal memeriksa');
      permissions.exactAlarmsError = StateError('gagal memeriksa');

      await pumpSettings(tester);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.settingsCheckFailed), findsNWidgets(2));
      expect(find.text(AppStrings.settingsActive), findsNothing);
    });

    testWidgets('kembali aktif menyegarkan status izin', (tester) async {
      await pumpSettings(tester);
      await tester.pumpAndSettle();
      expect(find.text(AppStrings.settingsActive), findsNWidgets(2));

      // Pengguna mematikan notifikasi lewat pengaturan sistem, lalu kembali
      // ke aplikasi.
      permissions.notificationsEnabledResult = false;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.settingsNotActive), findsOneWidget);
      expect(find.text(AppStrings.settingsOpenSystem), findsOneWidget);
      expect(permissions.notificationsChecks, greaterThan(1));
    });

    testWidgets('tinggi baris izin tetap sama saat status diperbarui',
        (tester) async {
      final pending = _PendingPermissions();
      getIt.unregister<ReminderPermissions>();
      getIt.registerSingleton<ReminderPermissions>(pending);

      await pumpSettings(tester);
      await tester.pump();
      final before = tester.getSize(
        find.byKey(const Key('permission-notifications')),
      );

      pending.notifications.complete(true);
      pending.exactAlarms.complete(true);
      await tester.pumpAndSettle();

      final after = tester.getSize(
        find.byKey(const Key('permission-notifications')),
      );
      expect(after.height, before.height);
    });
  });

  group('Gagal menyimpan di layar Pengaturan', () {
    testWidgets('kegagalan menulis menampilkan snackbar dan jam tetap tampil',
        (tester) async {
      repository.error = StateError('gagal menulis');

      await pumpSettings(tester);
      await tester.pumpAndSettle();
      expect(find.text(_formatTime(8, 0)), findsOneWidget);

      await cubit!.updateAllDayHourMinutes(600);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.byType(SnackBar), findsOneWidget);
      expect(find.text(AppStrings.settingsSaveFailed), findsOneWidget);
      expect(
        find.text(_formatTime(8, 0)),
        findsOneWidget,
        reason: 'nilai jam yang tampil tidak boleh berubah saat gagal menulis',
      );
      expect(tester.takeException(), isNull);
    });

    testWidgets('mengubah jam berhasil mengubah nilai yang tampil',
        (tester) async {
      await pumpSettings(tester);
      await tester.pumpAndSettle();

      await cubit!.updateAllDayHourMinutes(600);
      await tester.pumpAndSettle();

      expect(find.text(_formatTime(8, 0)), findsNothing);
      expect(find.text(_formatTime(10, 0)), findsOneWidget);
      expect(find.byType(SnackBar), findsNothing);
    });
  });

  group('Tentang aplikasi di layar Pengaturan', () {
    testWidgets('versi aplikasi diambil dari PackageInfo', (tester) async {
      PackageInfo.setMockInitialValues(
        appName: 'SyncDaily',
        packageName: 'com.syncdaily',
        version: '1.2.3',
        buildNumber: '42',
        buildSignature: '',
      );

      await pumpSettings(tester);
      await tester.pumpAndSettle();

      expect(find.text('1.2.3'), findsOneWidget);
    });

    testWidgets('tautan yang berhasil dibuka tidak menampilkan snackbar',
        (tester) async {
      final launcher = _FakeUrlLauncher();
      UrlLauncherPlatform.instance = launcher;

      await pumpSettings(tester);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(AppStrings.settingsRepository));
      await tester.tap(find.text(AppStrings.settingsRepository));
      await tester.pumpAndSettle();

      expect(launcher.launchCalls, 1);
      expect(find.byType(SnackBar), findsNothing);
    });

    testWidgets('tautan yang gagal dibuka menampilkan snackbar dan disalin',
        (tester) async {
      final launcher = _FakeUrlLauncher(result: false);
      UrlLauncherPlatform.instance = launcher;

      await pumpSettings(tester);
      await tester.pumpAndSettle();

      await tester.ensureVisible(find.text(AppStrings.settingsRepository));
      await tester.tap(find.text(AppStrings.settingsRepository));
      await tester.pumpAndSettle();

      expect(find.text(AppStrings.settingsOpenFailed), findsOneWidget);
      expect(
        clipboardText,
        'https://github.com/Athif24/MySyncDaily',
        reason: 'tautan harus disalin ke papan klip saat tidak bisa dibuka',
      );
    });
  });

  group('Tata letak layar Pengaturan', () {
    for (final size in const [Size(400, 800), Size(320, 640)]) {
      for (final textScale in const [1.0, 1.3]) {
        testWidgets(
          'tanpa luapan pada $size dengan skala teks $textScale',
          (tester) async {
            await pumpSettings(tester, size: size, textScale: textScale);
            await tester.pumpAndSettle();

            expect(tester.takeException(), isNull);
            expect(find.text(AppStrings.settingsTitle), findsOneWidget);
          },
        );
      }
    }

    testWidgets('header tetap di atas, hanya isi yang bergulir', (tester) async {
      await pumpSettings(tester, size: const Size(320, 640));
      await tester.pumpAndSettle();

      final headerBefore = tester.getTopLeft(find.text(AppStrings.settingsTitle));
      final scrollView = find.byType(SingleChildScrollView);
      expect(scrollView, findsOneWidget);

      await tester.drag(scrollView, const Offset(0, -200));
      await tester.pumpAndSettle();

      final headerAfter = tester.getTopLeft(find.text(AppStrings.settingsTitle));
      expect(headerAfter, headerBefore);
      expect(tester.takeException(), isNull);
    });
  });
}
