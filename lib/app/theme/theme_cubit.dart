import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:veyra/core/storage/secure_storage_service.dart';

final class ThemeCubit extends Cubit<ThemeMode> {
  ThemeCubit(this._storage) : super(ThemeMode.light);

  final ThemeModeStorage _storage;

  Future<void> load() async {
    try {
      final ThemeMode? storedThemeMode = await _storage.readThemeMode();
      if (storedThemeMode != null && !isClosed) {
        emit(storedThemeMode);
      }
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }

  Future<void> toggle() async {
    final ThemeMode nextThemeMode = state == ThemeMode.dark
        ? ThemeMode.light
        : ThemeMode.dark;
    emit(nextThemeMode);

    try {
      await _storage.writeThemeMode(nextThemeMode);
    } on Object catch (error, stackTrace) {
      addError(error, stackTrace);
    }
  }
}
