import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/app/theme/theme_cubit.dart';
import 'package:veyra/core/storage/secure_storage_service.dart';

void main() {
  test('loads the persisted theme', () async {
    final InMemoryThemeModeStorage storage = InMemoryThemeModeStorage(
      initialValue: ThemeMode.dark,
    );
    final ThemeCubit cubit = ThemeCubit(storage);
    addTearDown(cubit.close);

    await cubit.load();

    expect(cubit.state, ThemeMode.dark);
  });

  test('toggles and saves the new theme', () async {
    final InMemoryThemeModeStorage storage = InMemoryThemeModeStorage();
    final ThemeCubit cubit = ThemeCubit(storage);
    addTearDown(cubit.close);

    await cubit.toggle();

    expect(cubit.state, ThemeMode.dark);
    expect(storage.value, ThemeMode.dark);
  });
}

final class InMemoryThemeModeStorage implements ThemeModeStorage {
  InMemoryThemeModeStorage({ThemeMode? initialValue}) : value = initialValue;

  ThemeMode? value;

  @override
  Future<ThemeMode?> readThemeMode() async => value;

  @override
  Future<void> writeThemeMode(ThemeMode themeMode) async {
    value = themeMode;
  }
}
