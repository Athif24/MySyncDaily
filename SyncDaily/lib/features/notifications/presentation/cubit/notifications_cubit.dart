import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/features/notifications/domain/app_messenger.dart';
import 'package:sync_daily/features/notifications/domain/entities/app_notification.dart';
import 'package:sync_daily/features/notifications/domain/notification_day_group.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_id.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_reconciler.dart';
import 'package:sync_daily/features/notifications/domain/notification_kind.dart';
import 'package:sync_daily/features/notifications/domain/reminder_synchronizer.dart';
import 'package:sync_daily/features/notifications/domain/repositories/notification_repository.dart';
import 'package:sync_daily/features/notifications/domain/task_detail_opener.dart';
import 'package:sync_daily/features/notifications/presentation/cubit/notifications_state.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_enums.dart';
import 'package:sync_daily/features/tasks/domain/repositories/task_repository.dart';

/// Cubit layar Notifikasi.
///
/// Menyalaraskan riwayat pengingat yang sudah berbunyi lebih dulu, lalu
/// berlangganan entri riwayat dan menyaringnya di sisi klien menurut jenis.
class NotificationsCubit extends Cubit<NotificationsState> {
  final NotificationRepository _notificationRepository;
  final TaskRepository _taskRepository;
  final TaskDetailOpener _opener;
  final AppMessenger _messenger;
  final ReminderSynchronizer _synchronizer;
  final NotificationHistoryReconciler _reconciler;

  /// Sumber waktu; bisa diganti pada pengujian.
  final DateTime Function() _now;

  StreamSubscription<List<AppNotification>>? _sub;

  List<AppNotification> _entries = const [];
  bool _failed = false;
  String? _errorMessage;

  NotificationsCubit({
    required NotificationRepository notificationRepository,
    required TaskRepository taskRepository,
    required TaskDetailOpener opener,
    required AppMessenger messenger,
    required ReminderSynchronizer synchronizer,
    required NotificationHistoryReconciler reconciler,
    DateTime Function()? now,
  })  : _notificationRepository = notificationRepository,
        _taskRepository = taskRepository,
        _opener = opener,
        _messenger = messenger,
        _synchronizer = synchronizer,
        _reconciler = reconciler,
        _now = now ?? DateTime.now,
        super(NotificationsState(today: _dateOnly((now ?? DateTime.now)())));

  /// Menyalaraskan riwayat lalu berlangganan entri.
  void start() {
    unawaited(_subscribe());
  }

  Future<void> _subscribe() async {
    // Pastikan kemunculan pengingat terbaru sudah dibentuk menjadi entri
    // sebelum menampilkan daftar.
    await _reconciler.reconcile();
    if (isClosed) {
      return;
    }
    unawaited(_sub?.cancel());
    _sub = _notificationRepository.watchNotifications().listen(
      (entries) {
        _failed = false;
        _entries = entries;
        _recompute();
      },
      onError: (Object error) {
        _failed = true;
        _errorMessage = '$error';
        _recompute();
      },
    );
  }

  /// Memuat ulang setelah error.
  void retry() {
    _failed = false;
    emit(state.copyWith(
      status: NotificationsStatus.loading,
      clearError: true,
    ));
    start();
  }

  /// Memilih jenis; `null` berarti "Semua".
  void setKind(NotificationKind? kind) {
    emit(state.copyWith(kind: kind, clearKind: kind == null));
    _recompute();
  }

  /// Menandai semua entri dibaca.
  Future<void> markAllRead() => _notificationRepository.markAllRead();

  /// Menangani ketukan entri: tandai dibaca, lalu buka detail tugasnya.
  ///
  /// Bila entri bukan berasal dari tugas, atau tugasnya sudah hilang, entri
  /// tetap ditandai dibaca dan pemakai diberi tahu lewat snackbar (tanpa
  /// membuka layar kosong).
  Future<void> openEntry(AppNotification entry) async {
    await _markRead(entry);
    final taskId = entry.entityId;
    if (entry.entityType != notificationTaskEntityType || taskId == null) {
      return;
    }
    final task = await _taskRepository.getTask(taskId);
    if (task == null || task.isDeleted) {
      _messenger.showSnackBar(AppStrings.taskNotFound);
      return;
    }
    _opener.open(taskId);
  }

  /// Aksi "Selesai": tandai tugas selesai, tandai entri dibaca, beri konfirmasi.
  Future<void> markDone(AppNotification entry) async {
    final taskId = entry.entityId;
    if (taskId == null) {
      return;
    }
    await _taskRepository.setStatus(taskId, TaskStatus.done);
    await _markRead(entry);
    _messenger.showSnackBar(AppStrings.notificationDoneConfirmation);
  }

  /// Aksi "Tunda 10 menit": jadwalkan tunda, tandai entri dibaca, beri
  /// konfirmasi.
  ///
  /// Untuk tugas yang sudah selesai, [ReminderSynchronizer.snooze] tidak
  /// menjadwalkan apa pun.
  Future<void> snooze(AppNotification entry) async {
    final taskId = entry.entityId;
    if (taskId == null) {
      return;
    }
    await _synchronizer.snooze(taskId);
    await _markRead(entry);
    _messenger.showSnackBar(AppStrings.notificationSnoozedConfirmation);
  }

  Future<void> _markRead(AppNotification entry) async {
    if (entry.isRead) {
      return;
    }
    await _notificationRepository.markRead(entry.id);
  }

  void _recompute() {
    final kind = state.kind;
    final visible = kind == null
        ? _entries
        : _entries.where((entry) => kind.matches(entry.type)).toList();

    emit(state.copyWith(
      status: _failed ? NotificationsStatus.error : NotificationsStatus.loaded,
      allEntries: _entries,
      visibleEntries: visible,
      groups: groupNotificationsByDay(visible),
      today: _dateOnly(_now()),
      errorMessage: _failed ? _errorMessage : null,
      clearError: !_failed,
    ));
  }

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
