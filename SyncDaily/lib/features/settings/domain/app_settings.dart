import 'package:equatable/equatable.dart';

class AppSettings extends Equatable {
  final bool defaultsEnabled;
  final int allDayReminderHourMinutes;
  final int reminderOnTimeMinutes; // 0
  final int eventTenMinutes; // 10
  final int taskTenMinutes; // 10
  final int milestoneTenMinutes; // 10
  final int defaultPreReminderMinutes; // for event/task/milestone (10 default)

  const AppSettings({
    this.defaultsEnabled = true,
    this.allDayReminderHourMinutes = 480,
    this.reminderOnTimeMinutes = 0,
    this.eventTenMinutes = 10,
    this.taskTenMinutes = 10,
    this.milestoneTenMinutes = 10,
    this.defaultPreReminderMinutes = 10,
  });

  AppSettings copyWith({
    bool? defaultsEnabled,
    int? allDayReminderHourMinutes,
    int? reminderOnTimeMinutes,
    int? eventTenMinutes,
    int? taskTenMinutes,
    int? milestoneTenMinutes,
    int? defaultPreReminderMinutes,
  }) {
    return AppSettings(
      defaultsEnabled: defaultsEnabled ?? this.defaultsEnabled,
      allDayReminderHourMinutes: allDayReminderHourMinutes ?? this.allDayReminderHourMinutes,
      reminderOnTimeMinutes: reminderOnTimeMinutes ?? this.reminderOnTimeMinutes,
      eventTenMinutes: eventTenMinutes ?? this.eventTenMinutes,
      taskTenMinutes: taskTenMinutes ?? this.taskTenMinutes,
      milestoneTenMinutes: milestoneTenMinutes ?? this.milestoneTenMinutes,
      defaultPreReminderMinutes: defaultPreReminderMinutes ?? this.defaultPreReminderMinutes,
    );
  }

  @override
  List<Object?> get props => [
        defaultsEnabled,
        allDayReminderHourMinutes,
        reminderOnTimeMinutes,
        eventTenMinutes,
        taskTenMinutes,
        milestoneTenMinutes,
        defaultPreReminderMinutes,
      ];
}
