import 'package:flutter/material.dart';
import 'package:veyra/core/security/security_config.dart';

abstract interface class ThemeModeStorage {
  Future<ThemeMode?> readThemeMode();

  Future<void> writeThemeMode(ThemeMode themeMode);
}

abstract interface class SecurityConfigStorage {
  Future<SecurityConfig?> readSecurityConfig();

  Future<void> writeSecurityConfig(SecurityConfig config);

  Future<bool> hasSecurityConfig();
}

abstract interface class SecureStorageService
    implements ThemeModeStorage, SecurityConfigStorage {}
