import 'package:go_router/go_router.dart';
import 'package:sync_daily/core/router/app_router.dart';
import 'package:sync_daily/features/notifications/domain/task_detail_opener.dart';

/// Membuka detail tugas lewat [GoRouter] aplikasi.
///
/// [router] bisa diganti pada pengujian. Bila rute teratas sudah merupakan
/// detail tugas yang sama, pembukaan dilewati supaya tidak menumpuk.
class GoRouterTaskDetailOpener implements TaskDetailOpener {
  final GoRouter _router;

  GoRouterTaskDetailOpener({GoRouter? router})
      : _router = router ?? AppRouter.router;

  @override
  void open(String taskId) {
    final location = '/tasks/$taskId';
    final topPath = _router.routerDelegate.currentConfiguration.uri.path;
    if (topPath == location) {
      return;
    }
    _router.push(location);
  }
}
