import 'package:flutter_test/flutter_test.dart';
import 'package:sync_daily/core/di/injection.dart';
import 'package:sync_daily/features/settings/presentation/cubit/settings_cubit.dart';

import '../../helpers/test_dependencies.dart';

/// Siklus hidup [SettingsCubit] di get_it.
///
/// Kubit ini berlangganan stream repository di konstruktornya. Bila getIt
/// melepasnya tanpa menutup kubit, langganan itu bocor antar-tes (satu isolate
/// menjalankan banyak berkas tes). Karena itu registrasinya memakai `dispose`.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('getIt.reset menutup SettingsCubit dan instance berikutnya dibuat ulang',
      () async {
    final db1 = await setUpInMemoryDependencies();
    addTearDown(db1.close);

    final cubit = getIt<SettingsCubit>();
    expect(
      identical(cubit, getIt<SettingsCubit>()),
      isTrue,
      reason: 'lazy singleton: satu instance dipakai halaman Pengaturan',
    );
    expect(cubit.isClosed, isFalse);

    await getIt.reset();
    expect(
      cubit.isClosed,
      isTrue,
      reason: 'reset() harus menutup kubit supaya langganan stream tidak bocor',
    );

    // Setelah reset seluruh registrasi terhapus; pasang ulang dependensi dulu
    // sebelum memeriksa bahwa instance berikutnya bukan instance lama.
    final db2 = await setUpInMemoryDependencies();
    addTearDown(db2.close);

    final baru = getIt<SettingsCubit>();
    addTearDown(baru.close);
    expect(
      identical(cubit, baru),
      isFalse,
      reason: 'setelah reset, kubit dibuat ulang (bukan instance lama)',
    );
  });
}
