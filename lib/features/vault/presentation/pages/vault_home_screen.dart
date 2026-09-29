import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:veyra/app/router/app_routes.dart';
import 'package:veyra/app/theme/theme_toggle_button.dart';
import 'package:veyra/features/vault/presentation/cubit/vault_home_cubit.dart';
import 'package:veyra/features/vault/presentation/cubit/vault_home_state.dart';
import 'package:veyra/features/vault/presentation/widgets/vault_category_card.dart';

final class VaultHomeScreen extends StatelessWidget {
  const VaultHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi bóveda'),
        actions: const <Widget>[ThemeToggleButton(), SizedBox(width: 8)],
      ),
      body: BlocBuilder<VaultHomeCubit, VaultHomeState>(
        builder: (context, state) {
          return SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
              children: <Widget>[
                VaultCategoryCard(
                  key: const ValueKey<String>('category-images'),
                  title: 'Imágenes',
                  icon: Icons.image_outlined,
                  itemCount: state.imageCount,
                  onTap: () async {
                    await context.pushNamed(AppRoutes.imagesVaultName);
                    if (context.mounted) {
                      await context.read<VaultHomeCubit>().loadCounts();
                    }
                  },
                ),
                const SizedBox(height: 16),
                VaultCategoryCard(
                  key: const ValueKey<String>('category-videos'),
                  title: 'Videos',
                  icon: Icons.movie_outlined,
                  itemCount: state.videoCount,
                  onTap: () async {
                    await context.pushNamed(AppRoutes.videosVaultName);
                    if (context.mounted) {
                      await context.read<VaultHomeCubit>().loadCounts();
                    }
                  },
                ),
                const SizedBox(height: 16),
                VaultCategoryCard(
                  key: const ValueKey<String>('category-files'),
                  title: 'Archivos',
                  icon: Icons.insert_drive_file_outlined,
                  itemCount: state.fileCount,
                  onTap: () async {
                    await context.pushNamed(AppRoutes.filesVaultName);
                    if (context.mounted) {
                      await context.read<VaultHomeCubit>().loadCounts();
                    }
                  },
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
