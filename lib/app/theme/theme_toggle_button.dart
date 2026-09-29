import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:veyra/app/theme/theme_cubit.dart';

final class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ThemeCubit, ThemeMode>(
      builder: (context, themeMode) {
        final bool isDark = themeMode == ThemeMode.dark;

        return IconButton(
          key: const ValueKey<String>('theme-toggle'),
          tooltip: isDark ? 'Activar tema claro' : 'Activar tema oscuro',
          onPressed: () async {
            await context.read<ThemeCubit>().toggle();
          },
          icon: Icon(
            isDark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
          ),
        );
      },
    );
  }
}
