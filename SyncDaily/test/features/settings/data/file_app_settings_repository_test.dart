import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:sync_daily/features/settings/data/file_app_settings_repository.dart';
import 'package:sync_daily/features/settings/domain/app_settings.dart';

/// Tes repository pengaturan berbasis berkas JSON.
///
/// Direktori penyimpanan diinjeksi lewat parameter konstruktor
/// (`supportDir`) supaya tes tidak bergantung pada `path_provider` (yang hanya
/// ada di perangkat). Bawaan produksi tetap `getApplicationSupportDirectory()`.
void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('sync_daily_settings_');
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  File mainFile() => File(p.join(tempDir.path, 'app_settings.json'));
  File tmpFile() => File(p.join(tempDir.path, 'app_settings.json.tmp'));

  FileAppSettingsRepository buildRepository() =>
      FileAppSettingsRepository(supportDir: tempDir);

  group('File.rename di platform ini', () {
    test('menimpa berkas yang sudah ada (bukti Windows untuk A3)', () async {
      final target = File(p.join(tempDir.path, 'target.json'));
      await target.writeAsString('lama');
      final source = File(p.join(tempDir.path, 'sumber.tmp'));
      await source.writeAsString('baru');

      await source.rename(target.path);

      expect(target.existsSync(), isTrue);
      expect(await target.readAsString(), 'baru');
      expect(source.existsSync(), isFalse);
    });
  });

  group('FileAppSettingsRepository.init', () {
    test('berkas hilang -> bawaan', () async {
      final repository = buildRepository();

      await repository.init();

      expect(repository.settings, const AppSettings());
      expect(repository.settings.allDayReminderHourMinutes, 480);
    });

    test('JSON rusak -> bawaan', () async {
      await mainFile().writeAsString('{ini bukan json');

      final repository = buildRepository();
      await repository.init();

      expect(repository.settings, const AppSettings());
    });

    test('JSON bukan Map -> bawaan', () async {
      await mainFile().writeAsString(jsonEncode([1, 2, 3]));

      final repository = buildRepository();
      await repository.init();

      expect(repository.settings, const AppSettings());
    });

    test('version asing -> bawaan', () async {
      await mainFile().writeAsString(
        jsonEncode({'version': 99, 'allDayReminderHourMinutes': 600}),
      );

      final repository = buildRepository();
      await repository.init();

      expect(repository.settings, const AppSettings());
      expect(repository.settings.allDayReminderHourMinutes, 480);
    });

    test('bidang tak dikenal diabaikan', () async {
      await mainFile().writeAsString(
        jsonEncode({
          'version': 1,
          'allDayReminderHourMinutes': 600,
          'masaDepan': 'nilai asing',
        }),
      );

      final repository = buildRepository();
      await repository.init();

      expect(repository.settings.allDayReminderHourMinutes, 600);
      expect(repository.settings.defaultsEnabled, isTrue);
    });

    test('bidang yang hilang memakai bawaan per bidang', () async {
      await mainFile().writeAsString(
        jsonEncode({'version': 1, 'allDayReminderHourMinutes': 600}),
      );

      final repository = buildRepository();
      await repository.init();

      expect(repository.settings.allDayReminderHourMinutes, 600);
      expect(repository.settings.defaultsEnabled, isTrue);
      expect(repository.settings.reminderOnTimeMinutes, 0);
      expect(repository.settings.eventTenMinutes, 10);
      expect(repository.settings.taskTenMinutes, 10);
      expect(repository.settings.milestoneTenMinutes, 10);
      expect(repository.settings.defaultPreReminderMinutes, 10);
    });

    test('menit di bawah 0 kembali ke bawaan (bukan dijepit)', () async {
      await mainFile().writeAsString(
        jsonEncode({'version': 1, 'allDayReminderHourMinutes': -30}),
      );

      final repository = buildRepository();
      await repository.init();

      expect(repository.settings.allDayReminderHourMinutes, 480);
    });

    test('menit di atas 1439 kembali ke bawaan (bukan dijepit)', () async {
      await mainFile().writeAsString(
        jsonEncode({'version': 1, 'allDayReminderHourMinutes': 1500}),
      );

      final repository = buildRepository();
      await repository.init();

      expect(repository.settings.allDayReminderHourMinutes, 480);
    });

    test('nilai di dalam rentang diterima apa adanya', () async {
      await mainFile().writeAsString(
        jsonEncode({'version': 1, 'allDayReminderHourMinutes': 1230}),
      );

      final repository = buildRepository();
      await repository.init();

      expect(repository.settings.allDayReminderHourMinutes, 1230);
    });
  });

  group('FileAppSettingsRepository.update', () {
    test('berhasil: tersimpan dan dapat dibaca ulang', () async {
      final repository = buildRepository();
      await repository.init();

      await repository.update(
        const AppSettings(allDayReminderHourMinutes: 600),
      );

      expect(repository.settings.allDayReminderHourMinutes, 600);

      final pembaca = buildRepository();
      await pembaca.init();
      expect(pembaca.settings.allDayReminderHourMinutes, 600);
    });

    test('berhasil: tidak ada berkas .tmp yang tertinggal', () async {
      final repository = buildRepository();
      await repository.init();

      await repository.update(
        const AppSettings(allDayReminderHourMinutes: 600),
      );

      expect(tmpFile().existsSync(), isFalse);
      expect(mainFile().existsSync(), isTrue);
    });

    test('berhasil: berkas utama ditimpa, bukan digandakan', () async {
      final repository = buildRepository();
      await repository.init();

      await repository.update(
        const AppSettings(allDayReminderHourMinutes: 600),
      );
      await repository.update(
        const AppSettings(allDayReminderHourMinutes: 900),
      );

      final isi = jsonDecode(await mainFile().readAsString()) as Map;
      expect(isi['allDayReminderHourMinutes'], 900);
      expect(isi['version'], 1);
      expect(tmpFile().existsSync(), isFalse);
    });

    test('nilai di luar rentang disimpan sebagai bawaan', () async {
      final repository = buildRepository();
      await repository.init();

      await repository.update(
        const AppSettings(allDayReminderHourMinutes: 1500),
      );

      expect(repository.settings.allDayReminderHourMinutes, 480);
    });

    test('gagal menulis: galat dilempar dan nilai di cache tidak berubah',
        () async {
      final repository = buildRepository();
      await repository.init();
      await repository.update(
        const AppSettings(allDayReminderHourMinutes: 600),
      );

      // Buat jalur .tmp menjadi direktori sehingga penulisan gagal.
      await Directory(tmpFile().path).create();
      final nilaiSebelum = repository.settings;

      await expectLater(
        repository.update(
          const AppSettings(allDayReminderHourMinutes: 900),
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(repository.settings, nilaiSebelum);
      expect(repository.settings.allDayReminderHourMinutes, 600);
    });

    test('gagal menulis: berkas utama tetap ada (tidak hilang di tengah)',
        () async {
      final repository = buildRepository();
      await repository.init();
      await repository.update(
        const AppSettings(allDayReminderHourMinutes: 600),
      );
      final isiSebelum = await mainFile().readAsString();

      await Directory(tmpFile().path).create();

      await expectLater(
        repository.update(
          const AppSettings(allDayReminderHourMinutes: 900),
        ),
        throwsA(isA<FileSystemException>()),
      );

      expect(mainFile().existsSync(), isTrue);
      expect(await mainFile().readAsString(), isiSebelum);
    });
  });

  group('FileAppSettingsRepository.reset', () {
    test('mengembalikan nilai ke bawaan dan menghapus berkas simpan', () async {
      final repository = buildRepository();
      await repository.init();
      await repository.update(
        const AppSettings(allDayReminderHourMinutes: 600),
      );
      expect(mainFile().existsSync(), isTrue);

      await repository.reset();

      expect(repository.settings, const AppSettings());
      expect(mainFile().existsSync(), isFalse);
    });
  });
}
