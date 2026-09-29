import 'package:flutter/material.dart';

abstract final class AppPalette {
  static const Color brand = Color(0xFF315DA8);
}

@immutable
final class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.success,
    required this.onSuccess,
    required this.warning,
    required this.onWarning,
    required this.danger,
    required this.onDanger,
    required this.secureSurface,
  });

  static const AppSemanticColors light = AppSemanticColors(
    success: Color(0xFF146C43),
    onSuccess: Color(0xFFFFFFFF),
    warning: Color(0xFF8A4B00),
    onWarning: Color(0xFFFFFFFF),
    danger: Color(0xFFB3261E),
    onDanger: Color(0xFFFFFFFF),
    secureSurface: Color(0xFFE8EEFA),
  );

  static const AppSemanticColors dark = AppSemanticColors(
    success: Color(0xFF70DBA4),
    onSuccess: Color(0xFF003921),
    warning: Color(0xFFFFB86C),
    onWarning: Color(0xFF492900),
    danger: Color(0xFFFFB4AB),
    onDanger: Color(0xFF690005),
    secureSurface: Color(0xFF192232),
  );

  final Color success;
  final Color onSuccess;
  final Color warning;
  final Color onWarning;
  final Color danger;
  final Color onDanger;
  final Color secureSurface;

  @override
  AppSemanticColors copyWith({
    Color? success,
    Color? onSuccess,
    Color? warning,
    Color? onWarning,
    Color? danger,
    Color? onDanger,
    Color? secureSurface,
  }) {
    return AppSemanticColors(
      success: success ?? this.success,
      onSuccess: onSuccess ?? this.onSuccess,
      warning: warning ?? this.warning,
      onWarning: onWarning ?? this.onWarning,
      danger: danger ?? this.danger,
      onDanger: onDanger ?? this.onDanger,
      secureSurface: secureSurface ?? this.secureSurface,
    );
  }

  @override
  AppSemanticColors lerp(covariant AppSemanticColors? other, double t) {
    if (other == null) {
      return this;
    }

    return AppSemanticColors(
      success: Color.lerp(success, other.success, t) ?? success,
      onSuccess: Color.lerp(onSuccess, other.onSuccess, t) ?? onSuccess,
      warning: Color.lerp(warning, other.warning, t) ?? warning,
      onWarning: Color.lerp(onWarning, other.onWarning, t) ?? onWarning,
      danger: Color.lerp(danger, other.danger, t) ?? danger,
      onDanger: Color.lerp(onDanger, other.onDanger, t) ?? onDanger,
      secureSurface:
          Color.lerp(secureSurface, other.secureSurface, t) ?? secureSurface,
    );
  }
}
