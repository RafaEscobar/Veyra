import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/app/theme/app_colors.dart';
import 'package:veyra/app/theme/app_theme.dart';

void main() {
  test('provides light and dark themes with semantic colors', () {
    expect(AppTheme.lightTheme.brightness, Brightness.light);
    expect(AppTheme.darkTheme.brightness, Brightness.dark);
    expect(
      AppTheme.lightTheme.extension<AppSemanticColors>(),
      AppSemanticColors.light,
    );
    expect(
      AppTheme.darkTheme.extension<AppSemanticColors>(),
      AppSemanticColors.dark,
    );
  });

  test('semantic status colors meet WCAG AA text contrast', () {
    _expectAccessiblePair(
      AppSemanticColors.light.success,
      AppSemanticColors.light.onSuccess,
    );
    _expectAccessiblePair(
      AppSemanticColors.light.warning,
      AppSemanticColors.light.onWarning,
    );
    _expectAccessiblePair(
      AppSemanticColors.light.danger,
      AppSemanticColors.light.onDanger,
    );
    _expectAccessiblePair(
      AppSemanticColors.dark.success,
      AppSemanticColors.dark.onSuccess,
    );
    _expectAccessiblePair(
      AppSemanticColors.dark.warning,
      AppSemanticColors.dark.onWarning,
    );
    _expectAccessiblePair(
      AppSemanticColors.dark.danger,
      AppSemanticColors.dark.onDanger,
    );
  });

  test('interactive controls keep a minimum 48 pixel touch target', () {
    final ButtonStyle? filledStyle =
        AppTheme.lightTheme.filledButtonTheme.style;
    expect(
      filledStyle?.minimumSize?.resolve(<WidgetState>{}),
      const Size(48, 48),
    );
    expect(
      AppTheme.lightTheme.iconButtonTheme.style?.minimumSize?.resolve(
        <WidgetState>{},
      ),
      const Size(48, 48),
    );
    expect(
      AppTheme.lightTheme.materialTapTargetSize,
      MaterialTapTargetSize.padded,
    );
  });
}

void _expectAccessiblePair(Color background, Color foreground) {
  final double backgroundLuminance = background.computeLuminance();
  final double foregroundLuminance = foreground.computeLuminance();
  final double lighter = backgroundLuminance > foregroundLuminance
      ? backgroundLuminance
      : foregroundLuminance;
  final double darker = backgroundLuminance > foregroundLuminance
      ? foregroundLuminance
      : backgroundLuminance;
  final double contrastRatio = (lighter + 0.05) / (darker + 0.05);

  expect(contrastRatio, greaterThanOrEqualTo(4.5));
}
