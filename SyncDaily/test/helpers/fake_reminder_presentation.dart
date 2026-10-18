import 'package:sync_daily/features/notifications/domain/app_messenger.dart';
import 'package:sync_daily/features/notifications/domain/task_detail_opener.dart';

/// Pembuka detail tugas palsu yang mencatat pemanggilan.
class FakeTaskDetailOpener implements TaskDetailOpener {
  final List<String> openedTaskIds = <String>[];

  @override
  void open(String taskId) {
    openedTaskIds.add(taskId);
  }
}

/// Penyampai pesan palsu yang mencatat snackbar.
class FakeAppMessenger implements AppMessenger {
  final List<String> messages = <String>[];

  @override
  void showSnackBar(String message) => messages.add(message);
}
