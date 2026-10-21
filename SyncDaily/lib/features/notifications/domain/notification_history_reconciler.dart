import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_builder.dart';
import 'package:sync_daily/features/notifications/domain/repositories/notification_repository.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_recurrence.dart';
import 'package:sync_daily/features/tasks/domain/entities/task_reminder.dart';
import 'package:sync_daily/features/tasks/domain/repositories/task_repository.dart';

/// Membentuk riwayat notifikasi dari pengingat yang sudah berbunyi.
///
/// Dijalankan saat aplikasi dibuka/dilanjutkan (lihat `main.dart`) dan saat
/// halaman Notifikasi dibuka. Bersifat idempoten: entri memakai kunci
/// deterministik dan disisipkan "bila belum ada", jadi `isRead` yang sudah
/// ditandai pengguna tidak pernah ditimpa.
///
/// Tanpa penanda air (watermark): jendela yang ditelusuri dibatasi [lookback]
/// saja, dan riwayat lama dibuang sesuai [retention]/[maxEntries]. Ini
/// menghindari penyimpanan keadaan tambahan sekaligus menjaga biaya tetap.
class NotificationHistoryReconciler {
  /// Seberapa jauh ke belakang kemunculan ditelusuri.
  static const Duration defaultLookback = Duration(days: 7);

  /// Umur maksimal entri riwayat sebelum dihapus permanen.
  static const Duration defaultRetention = Duration(days: 30);

  /// Batas jumlah entri riwayat yang disimpan.
  static const int defaultMaxEntries = 200;

  final TaskRepository _taskRepository;
  final NotificationRepository _notificationRepository;
  final DateTime Function() _now;
  final Duration _lookback;
  final Duration _retention;
  final int _maxEntries;
  final Duration _minInterval;

  DateTime? _lastRunAt;
  Future<void>? _active;

  NotificationHistoryReconciler({
    required TaskRepository taskRepository,
    required NotificationRepository notificationRepository,
    DateTime Function()? now,
    Duration lookback = defaultLookback,
    Duration retention = defaultRetention,
    int maxEntries = defaultMaxEntries,
    Duration minInterval = const Duration(seconds: 5),
  })  : _taskRepository = taskRepository,
        _notificationRepository = notificationRepository,
        _now = now ?? DateTime.now,
        _lookback = lookback,
        _retention = retention,
        _maxEntries = maxEntries,
        _minInterval = minInterval;

  /// Menyelaraskan riwayat dengan pengingat yang sudah berbunyi.
  ///
  /// Bila sudah ada proses berjalan, panggilan ini MENUNGGU proses yang sama
  /// (bukan langsung kembali), supaya pemanggil seperti siklus hidup aplikasi
  /// benar-benar tahu riwayat sudah selesai dibentuk sebelum langkah berikutnya
  /// (mis. menandai entri dibaca) dijalankan.
  Future<void> reconcile({bool force = false}) async {
    final active = _active;
    if (active != null) {
      await active;
      return;
    }
    final now = _now();
    final last = _lastRunAt;
    if (!force && last != null && now.difference(last) < _minInterval) {
      return;
    }

    final future = _reconcileOnce(now);
    _active = future;
    try {
      await future;
    } finally {
      _active = null;
    }
  }

  Future<void> _reconcileOnce(DateTime now) async {
    try {
      final tasks = await _taskRepository.getAllTasks();
      final reminders = await _taskRepository.getAllReminders();
      final recurrences = await _taskRepository.getAllRecurrences();

      final remindersByTask = <String, List<TaskReminder>>{};
      for (final reminder in reminders) {
        remindersByTask.putIfAbsent(reminder.taskId, () => []).add(reminder);
      }
      final recurrenceByTask = <String, TaskRecurrence>{
        for (final recurrence in recurrences) recurrence.taskId: recurrence,
      };

      final entries = NotificationHistoryBuilder.build(
        tasks: tasks,
        remindersByTask: remindersByTask,
        recurrenceByTask: recurrenceByTask,
        now: now,
        lookback: _lookback,
      );
      for (final entry in entries) {
        await _notificationRepository.insertIfAbsent(entry);
      }
      await _notificationRepository.pruneHistory(
        olderThan: now.subtract(_retention).toUtc(),
        keepNewerThan: now.subtract(_lookback).toUtc(),
        maxEntries: _maxEntries,
      );
      _lastRunAt = now;
    } catch (error) {
      debugPrint('[SyncDaily] Gagal menyusun riwayat notifikasi: $error');
    }
  }
}
