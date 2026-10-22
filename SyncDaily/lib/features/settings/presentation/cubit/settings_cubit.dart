import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:sync_daily/core/strings/app_strings.dart';
import 'package:sync_daily/features/notifications/domain/notification_history_reconciler.dart';
import 'package:sync_daily/features/notifications/domain/reminder_synchronizer.dart';
import 'package:sync_daily/features/settings/domain/app_settings.dart';
import 'package:sync_daily/features/settings/domain/app_settings_repository.dart';

part 'settings_state.dart';

class SettingsCubit extends Cubit<SettingsState> {
  SettingsCubit({
    required AppSettingsRepository repository,
    required NotificationHistoryReconciler reconciler,
    required ReminderSynchronizer synchronizer,
  })  : _repository = repository,
        _reconciler = reconciler,
        _synchronizer = synchronizer,
        super(SettingsState.initial(repository.settings)) {
    _sub = _repository.stream.listen((s) {
      emit(state.copyWith(settings: s));
    });
  }

  final AppSettingsRepository _repository;
  final NotificationHistoryReconciler _reconciler;
  final ReminderSynchronizer _synchronizer;
  StreamSubscription<AppSettings>? _sub;

  Future<void> update(AppSettings settings) async {
    await _repository.update(settings);
  }

  /// Mengubah jam bunyi item seharian.
  ///
  /// Kegagalan tidak boleh menghentikan aplikasi: pesan kesalahan dibawa lewat
  /// [SettingsState.errorMessage] supaya layar bisa menampilkan snackbar,
  /// sedangkan nilai jam yang tampil tetap nilai lama (tidak berubah).
  Future<void> updateAllDayHourMinutes(int minutes) async {
    final old = _repository.settings;
    final clamped = minutes.clamp(0, 1439);
    try {
      // (E): build history with OLD hour first, save new, resyncAll(force:true)
      // Paksa dipakai agar riwayat tidak dilewati throttle 5 detik: tanpa itu,
      // riwayat yang harus dibangun dengan jam LAMA bisa terlewat.
      await _reconciler.reconcile(force: true);
      await _repository.update(old.copyWith(allDayReminderHourMinutes: clamped));
      await _synchronizer.resyncAll(force: true);
    } catch (_) {
      if (isClosed) {
        return;
      }
      emit(state.copyWith(errorMessage: AppStrings.settingsSaveFailed));
    }
  }

  /// Menghapus pesan error setelah pesan itu ditampilkan (biar tidak muncul
  /// dua kali untuk satu kegagalan).
  void clearError() {
    if (isClosed || state.errorMessage == null) {
      return;
    }
    emit(state.withoutError());
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
