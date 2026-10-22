import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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

  Future<void> updateAllDayHourMinutes(int minutes) async {
    final old = _repository.settings;
    final clamped = minutes.clamp(0, 1439);
    // (E): build history with OLD hour first, save new, resyncAll(force:true)
    await _reconciler.reconcile();
    await _repository.update(old.copyWith(allDayReminderHourMinutes: clamped));
    await _synchronizer.resyncAll(force: true);
  }

  @override
  Future<void> close() {
    _sub?.cancel();
    return super.close();
  }
}
