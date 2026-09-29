import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:veyra/core/security/security_config.dart';
import 'package:veyra/core/storage/secure_storage_service.dart';

final class FlutterSecureStorageService implements SecureStorageService {
  const FlutterSecureStorageService([
    this._storage = const FlutterSecureStorage(),
  ]);

  static const String _securityConfigKey = 'security.config.v1';
  static const String _themeModeKey = 'settings.theme_mode';
  static const String _lightThemeValue = 'light';
  static const String _darkThemeValue = 'dark';

  final FlutterSecureStorage _storage;

  @override
  Future<bool> hasSecurityConfig() async {
    return await _storage.read(key: _securityConfigKey) != null;
  }

  @override
  Future<SecurityConfig?> readSecurityConfig() async {
    final String? value = await _storage.read(key: _securityConfigKey);
    if (value == null) {
      return null;
    }
    return SecurityConfig.fromJsonString(value);
  }

  @override
  Future<ThemeMode?> readThemeMode() async {
    final String? storedValue = await _storage.read(key: _themeModeKey);
    return switch (storedValue) {
      _lightThemeValue => ThemeMode.light,
      _darkThemeValue => ThemeMode.dark,
      _ => null,
    };
  }

  @override
  Future<void> writeSecurityConfig(SecurityConfig config) {
    return _storage.write(
      key: _securityConfigKey,
      value: config.toJsonString(),
    );
  }

  @override
  Future<void> writeThemeMode(ThemeMode themeMode) {
    final String value = switch (themeMode) {
      ThemeMode.dark => _darkThemeValue,
      ThemeMode.light || ThemeMode.system => _lightThemeValue,
    };
    return _storage.write(key: _themeModeKey, value: value);
  }
}
