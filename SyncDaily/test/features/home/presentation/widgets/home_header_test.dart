import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/core/theme/app_sizes.dart';
import 'package:sync_daily/core/widgets/app_avatar.dart';
import 'package:sync_daily/features/home/presentation/widgets/home_header.dart';

/// Semantik avatar pada header Beranda: satu tombol berlabel "Pengaturan"
/// (bukan dua label: tombol + nama pengguna dari avatar).
void main() {
  late GoRouter router;

  setUp(() {
    router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => const Scaffold(
            body: HomeHeader(
              userName: 'Pengguna',
              greeting: 'Selamat pagi',
              unreadCount: 0,
            ),
          ),
        ),
        GoRoute(
          path: '/settings',
          builder: (context, state) =>
              const Scaffold(body: Text('Layar Pengaturan')),
        ),
      ],
    );
  });

  tearDown(() async {
    router.dispose();
  });

  testWidgets('avatar adalah tombol Pengaturan tanpa label nama ganda',
      (tester) async {
    final handle = tester.ensureSemantics();

    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final node = tester.getSemantics(find.byType(AppAvatar));
    expect(node.label, AppStrings.settingsTitle);
    expect(
      node.label,
      isNot(contains('Pengguna')),
      reason: 'label avatar tidak boleh menyatu dengan label tombol',
    );
    expect(node.flagsCollection.isButton, isTrue);

    handle.dispose();
  });

  testWidgets('area ketuk avatar minimal 44 dp', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    final tapArea = tester.getSize(find.byType(InkWell));
    expect(tapArea.width, greaterThanOrEqualTo(AppSizes.minTouchTarget));
    expect(tapArea.height, greaterThanOrEqualTo(AppSizes.minTouchTarget));
  });

  testWidgets('ketuk avatar membuka rute /settings', (tester) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AppAvatar));
    await tester.pumpAndSettle();

    expect(find.text('Layar Pengaturan'), findsOneWidget);
  });
}
