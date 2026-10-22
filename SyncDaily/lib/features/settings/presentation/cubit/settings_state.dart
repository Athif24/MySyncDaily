part of 'settings_cubit.dart';

class SettingsState extends Equatable {
  const SettingsState({required this.settings});

  final AppSettings settings;

  factory SettingsState.initial(AppSettings s) => SettingsState(settings: s);

  SettingsState copyWith({AppSettings? settings}) {
    return SettingsState(settings: settings ?? this.settings);
  }

  @override
  List<Object?> get props => [settings];
}
