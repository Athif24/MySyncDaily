import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sync_daily/features/settings/domain/app_settings.dart';
import 'package:sync_daily/features/settings/domain/app_settings_repository.dart';

class FileAppSettingsRepository implements AppSettingsRepository {
  FileAppSettingsRepository({Directory? supportDir})
      : _supportDir = supportDir;

  Directory? _supportDir;
  AppSettings _settings = const AppSettings();
  final _controller = StreamController<AppSettings>.broadcast();
  File? _file;

  static const _fileName = 'app_settings.json';
  static const _version = 1;

  @override
  AppSettings get settings => _settings;

  @override
  Stream<AppSettings> get stream => _controller.stream;

  Future<Directory> _dir() async {
    if (_supportDir != null) return _supportDir!;
    _supportDir = await getApplicationSupportDirectory();
    return _supportDir!;
  }

  Future<File> _fileObj() async {
    if (_file != null) return _file!;
    final dir = await _dir();
    _file = File(p.join(dir.path, _fileName));
    return _file!;
  }

  @override
  Future<void> init() async {
    try {
      final file = await _fileObj();
      if (!await file.exists()) {
        _settings = const AppSettings();
        _controller.add(_settings);
        return;
      }
      final raw = await file.readAsString();
      final decoded = jsonDecode(raw);
      if (decoded is! Map) {
        _settings = const AppSettings();
        _controller.add(_settings);
        return;
      }
      final version = decoded['version'];
      if (version != null && version != _version) {
        _settings = const AppSettings();
        _controller.add(_settings);
        return;
      }
      final allDay = _clampInt(decoded['allDayReminderHourMinutes'], 480);
      final defaultsEnabled = decoded['defaultsEnabled'] == false ? false : true;
      final reminderOnTime = _clampInt(decoded['reminderOnTimeMinutes'], 0);
      final eventTen = _clampInt(decoded['eventTenMinutes'], 10);
      final taskTen = _clampInt(decoded['taskTenMinutes'], 10);
      final milestoneTen = _clampInt(decoded['milestoneTenMinutes'], 10);
      final defaultPre = _clampInt(decoded['defaultPreReminderMinutes'], 10);
      _settings = AppSettings(
        defaultsEnabled: defaultsEnabled,
        allDayReminderHourMinutes: allDay,
        reminderOnTimeMinutes: reminderOnTime,
        eventTenMinutes: eventTen,
        taskTenMinutes: taskTen,
        milestoneTenMinutes: milestoneTen,
        defaultPreReminderMinutes: defaultPre,
      );
      _controller.add(_settings);
    } catch (_) {
      _settings = const AppSettings();
      _controller.add(_settings);
    }
  }

  int _clampInt(dynamic v, int def) {
    if (v is! int) return def;
    if (v < 0 || v > 1439) return def;
    return v;
  }

  @override
  Future<void> update(AppSettings settings) async {
    final clamped = AppSettings(
      defaultsEnabled: settings.defaultsEnabled,
      allDayReminderHourMinutes: _clampInt(settings.allDayReminderHourMinutes, 480),
      reminderOnTimeMinutes: _clampInt(settings.reminderOnTimeMinutes, 0),
      eventTenMinutes: _clampInt(settings.eventTenMinutes, 10),
      taskTenMinutes: _clampInt(settings.taskTenMinutes, 10),
      milestoneTenMinutes: _clampInt(settings.milestoneTenMinutes, 10),
      defaultPreReminderMinutes: _clampInt(settings.defaultPreReminderMinutes, 10),
    );
    try {
      final file = await _fileObj();
      final dir = file.parent;
      final tmp = File(p.join(dir.path, _fileName + '.tmp'));
      final map = <String, Object?>{
        'version': _version,
        'defaultsEnabled': clamped.defaultsEnabled,
        'allDayReminderHourMinutes': clamped.allDayReminderHourMinutes,
        'reminderOnTimeMinutes': clamped.reminderOnTimeMinutes,
        'eventTenMinutes': clamped.eventTenMinutes,
        'taskTenMinutes': clamped.taskTenMinutes,
        'milestoneTenMinutes': clamped.milestoneTenMinutes,
        'defaultPreReminderMinutes': clamped.defaultPreReminderMinutes,
      };
      await tmp.writeAsString(jsonEncode(map));
      if (await file.exists()) {
        await file.delete();
      }
      await tmp.rename(file.path);
      _settings = clamped;
      _controller.add(_settings);
    } catch (_) {
      // failure writing should not change displayed value
      rethrow;
    }
  }

  Future<void> dispose() async {
    await _controller.close();
  }
}
