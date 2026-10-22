part of 'settings_cubit.dart';

class SettingsState extends Equatable {
  const SettingsState({required this.settings, this.errorMessage});

  final AppSettings settings;

  /// Pesan singkat yang perlu ditampilkan sekali saja (mis. "gagal
  /// disimpan"). Null berarti tidak ada pesan baru.
  final String? errorMessage;

  factory SettingsState.initial(AppSettings s) =>
      SettingsState(settings: s);

  /// Menyalin state. [errorMessage] yang null berarti "tidak diubah"; untuk
  /// menghapus pesan gunakan [withoutError].
  SettingsState copyWith({AppSettings? settings, String? errorMessage}) {
    return SettingsState(
      settings: settings ?? this.settings,
      errorMessage: errorMessage ?? this.errorMessage,
    );
  }

  /// State tanpa pesan error (dipakai setelah pesan sudah ditampilkan).
  SettingsState withoutError() => SettingsState(settings: settings);

  @override
  List<Object?> get props => [settings, errorMessage];
}
