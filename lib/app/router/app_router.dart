import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:veyra/app/router/app_routes.dart';
import 'package:veyra/features/authentication/presentation/pages/unlock_page.dart';
import 'package:veyra/features/files/application/document_import_service.dart';
import 'package:veyra/features/files/application/document_vault_service.dart';
import 'package:veyra/features/files/presentation/cubit/document_import_cubit.dart';
import 'package:veyra/features/files/presentation/pages/files_vault_screen.dart';
import 'package:veyra/features/images/application/image_import_service.dart';
import 'package:veyra/features/images/application/image_vault_service.dart';
import 'package:veyra/features/images/presentation/cubit/image_import_cubit.dart';
import 'package:veyra/features/images/presentation/pages/images_vault_screen.dart';
import 'package:veyra/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:veyra/features/onboarding/presentation/pages/confirm_pin_page.dart';
import 'package:veyra/features/onboarding/presentation/pages/create_pin_page.dart';
import 'package:veyra/features/onboarding/presentation/pages/security_answer_page.dart';
import 'package:veyra/features/onboarding/presentation/pages/security_question_page.dart';
import 'package:veyra/features/onboarding/presentation/pages/setup_complete_page.dart';
import 'package:veyra/features/onboarding/presentation/pages/startup_page.dart';
import 'package:veyra/features/onboarding/presentation/pages/welcome_page.dart';
import 'package:veyra/features/recovery/domain/repositories/recovery_repository.dart';
import 'package:veyra/features/recovery/presentation/cubit/recovery_cubit.dart';
import 'package:veyra/features/recovery/presentation/pages/recovery_page.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';
import 'package:veyra/features/vault/presentation/cubit/vault_home_cubit.dart';
import 'package:veyra/features/vault/presentation/pages/vault_home_screen.dart';
import 'package:veyra/features/videos/application/video_import_service.dart';
import 'package:veyra/features/videos/application/video_vault_service.dart';
import 'package:veyra/features/videos/presentation/cubit/video_import_cubit.dart';
import 'package:veyra/features/videos/presentation/pages/videos_vault_screen.dart';

abstract final class AppRouter {
  static GoRouter create() {
    return GoRouter(
      initialLocation: AppRoutes.startupPath,
      routes: <RouteBase>[
        GoRoute(
          name: AppRoutes.startupName,
          path: AppRoutes.startupPath,
          builder: (context, state) =>
              StartupPage(repository: context.read<OnboardingRepository>()),
        ),
        GoRoute(
          name: AppRoutes.welcomeName,
          path: AppRoutes.welcomePath,
          builder: (context, state) => const WelcomePage(),
        ),
        GoRoute(
          name: AppRoutes.createPinName,
          path: AppRoutes.createPinPath,
          builder: (context, state) => const CreatePinPage(),
        ),
        GoRoute(
          name: AppRoutes.confirmPinName,
          path: AppRoutes.confirmPinPath,
          builder: (context, state) => const ConfirmPinPage(),
        ),
        GoRoute(
          name: AppRoutes.securityQuestionName,
          path: AppRoutes.securityQuestionPath,
          builder: (context, state) => const SecurityQuestionPage(),
        ),
        GoRoute(
          name: AppRoutes.securityAnswerName,
          path: AppRoutes.securityAnswerPath,
          builder: (context, state) => const SecurityAnswerPage(),
        ),
        GoRoute(
          name: AppRoutes.setupCompleteName,
          path: AppRoutes.setupCompletePath,
          builder: (context, state) => const SetupCompletePage(),
        ),
        GoRoute(
          name: AppRoutes.unlockName,
          path: AppRoutes.unlockPath,
          builder: (context, state) => UnlockPage(
            showRecoverySuccess: state.uri.queryParameters['recovered'] == '1',
          ),
        ),
        GoRoute(
          name: AppRoutes.recoveryName,
          path: AppRoutes.recoveryPath,
          builder: (context, state) => BlocProvider<RecoveryCubit>(
            create: (context) =>
                RecoveryCubit(context.read<RecoveryRepository>()),
            child: const RecoveryPage(),
          ),
        ),
        GoRoute(
          name: AppRoutes.vaultHomeName,
          path: AppRoutes.vaultHomePath,
          builder: (context, state) => BlocProvider<VaultHomeCubit>(
            create: (context) {
              final VaultHomeCubit cubit = VaultHomeCubit(
                context.read<VaultRepository>(),
              );
              unawaited(cubit.loadCounts());
              return cubit;
            },
            child: const VaultHomeScreen(),
          ),
        ),
        GoRoute(
          name: AppRoutes.imagesVaultName,
          path: AppRoutes.imagesVaultPath,
          builder: (context, state) => BlocProvider<ImageImportCubit>(
            create: (context) {
              final ImageImportCubit cubit = ImageImportCubit(
                context.read<ImageImportService>(),
                context.read<ImageVaultService>(),
              );
              unawaited(cubit.loadCount());
              return cubit;
            },
            child: const ImagesVaultScreen(),
          ),
        ),
        GoRoute(
          name: AppRoutes.videosVaultName,
          path: AppRoutes.videosVaultPath,
          builder: (context, state) => BlocProvider<VideoImportCubit>(
            create: (context) {
              final VideoImportCubit cubit = VideoImportCubit(
                context.read<VideoImportService>(),
                context.read<VideoVaultService>(),
              );
              unawaited(cubit.loadCount());
              return cubit;
            },
            child: const VideosVaultScreen(),
          ),
        ),
        GoRoute(
          name: AppRoutes.filesVaultName,
          path: AppRoutes.filesVaultPath,
          builder: (context, state) => BlocProvider<DocumentImportCubit>(
            create: (context) {
              final DocumentImportCubit cubit = DocumentImportCubit(
                context.read<DocumentImportService>(),
                context.read<DocumentVaultService>(),
              );
              unawaited(cubit.loadItems());
              return cubit;
            },
            child: const FilesVaultScreen(),
          ),
        ),
      ],
    );
  }
}
