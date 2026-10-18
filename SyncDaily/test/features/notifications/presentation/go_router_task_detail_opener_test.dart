import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:sync_daily/features/notifications/presentation/go_router_task_detail_opener.dart';

void main() {
  GoRouter buildRouter() => GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (context, state) => const Scaffold(
              body: Center(child: Text('Beranda')),
            ),
          ),
          GoRoute(
            path: '/tasks/:id',
            builder: (context, state) => Scaffold(
              appBar: AppBar(),
              body: Center(child: Text('Detail ${state.pathParameters['id']}')),
            ),
          ),
        ],
      );

  testWidgets(
      'ketukan saat detail tugas yang sama sudah di atas tumpukan tidak menumpuk',
      (tester) async {
    final router = buildRouter();
    final opener = GoRouterTaskDetailOpener(router: router);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    opener.open('t1');
    await tester.pumpAndSettle();
    expect(find.text('Detail t1'), findsOneWidget);

    opener.open('t1');
    await tester.pumpAndSettle();

    expect(
      find.text('Detail t1'),
      findsOneWidget,
      reason: 'detail yang sama tidak boleh ditumpuk',
    );
  });

  testWidgets(
      'ketukan dari layar lain membuka detail sekali dan kembali sekali',
      (tester) async {
    final router = buildRouter();
    final opener = GoRouterTaskDetailOpener(router: router);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    expect(find.text('Beranda'), findsOneWidget);

    opener.open('t1');
    await tester.pumpAndSettle();
    expect(find.text('Detail t1'), findsOneWidget);

    // Tombol kembali hanya sekali untuk kembali ke layar sebelumnya.
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();

    expect(find.text('Beranda'), findsOneWidget);
    expect(find.text('Detail t1'), findsNothing);
  });

  testWidgets('ketukan untuk tugas berbeda membuka detail tugas itu',
      (tester) async {
    final router = buildRouter();
    final opener = GoRouterTaskDetailOpener(router: router);
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));

    opener.open('t1');
    await tester.pumpAndSettle();
    opener.open('t2');
    await tester.pumpAndSettle();

    expect(find.text('Detail t2'), findsOneWidget);
  });
}
