import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:veyra/app/router/app_router.dart';
import 'package:veyra/app/router/app_routes.dart';
import 'package:veyra/app/theme/app_theme.dart';
import 'package:veyra/app/theme/theme_cubit.dart';
import 'package:veyra/core/constants/app_constants.dart';
import 'package:veyra/core/errors/app_error_handler.dart';
import 'package:veyra/core/performance/performance_monitor.dart';
import 'package:veyra/core/security/vault_auto_lock_manager.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/core/storage/flutter_secure_storage_service.dart';
import 'package:veyra/core/storage/secure_storage_service.dart';
import 'package:veyra/features/authentication/data/repositories/secure_authentication_repository.dart';
import 'package:veyra/features/authentication/domain/repositories/authentication_repository.dart';
import 'package:veyra/features/authentication/presentation/cubit/unlock_cubit.dart';
import 'package:veyra/features/authentication/presentation/cubit/unlock_state.dart';
import 'package:veyra/features/files/application/document_import_service.dart';
import 'package:veyra/features/files/application/document_vault_service.dart';
import 'package:veyra/features/files/data/repositories/file_picker_document_repository.dart';
import 'package:veyra/features/files/domain/repositories/document_picker_repository.dart';
import 'package:veyra/features/images/application/image_import_service.dart';
import 'package:veyra/features/images/application/image_vault_service.dart';
import 'package:veyra/features/images/data/repositories/photo_manager_image_library_repository.dart';
import 'package:veyra/features/images/domain/repositories/image_library_repository.dart';
import 'package:veyra/features/onboarding/data/repositories/secure_onboarding_repository.dart';
import 'package:veyra/features/onboarding/domain/repositories/onboarding_repository.dart';
import 'package:veyra/features/onboarding/presentation/cubit/onboarding_cubit.dart';
import 'package:veyra/features/recovery/data/repositories/secure_recovery_repository.dart';
import 'package:veyra/features/recovery/domain/repositories/recovery_repository.dart';
import 'package:veyra/features/vault/application/vault_export_service.dart';
import 'package:veyra/features/vault/data/database/vault_database.dart';
import 'package:veyra/features/vault/data/database/vault_items_dao.dart';
import 'package:veyra/features/vault/data/export/method_channel_external_file_destination.dart';
import 'package:veyra/features/vault/data/repositories/local_vault_repository.dart';
import 'package:veyra/features/vault/data/storage/private_temporary_file_manager.dart';
import 'package:veyra/features/vault/data/storage/private_vault_file_storage.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';
import 'package:veyra/features/vault/domain/services/temporary_file_manager.dart';
import 'package:veyra/features/vault/domain/services/vault_file_storage.dart';
import 'package:veyra/features/videos/application/video_import_service.dart';
import 'package:veyra/features/videos/application/video_vault_service.dart';
import 'package:veyra/features/videos/data/repositories/photo_manager_video_library_repository.dart';
import 'package:veyra/features/videos/domain/repositories/video_library_repository.dart';

final class VeyraApp extends StatefulWidget {
  const VeyraApp({
    super.key,
    this.themeModeStorage,
    this.secureStorageService,
    this.onboardingRepository,
    this.authenticationRepository,
    this.recoveryRepository,
    this.vaultRepository,
    this.vaultSession,
    this.imageLibraryRepository,
    this.imageImportService,
    this.imageVaultService,
    this.videoLibraryRepository,
    this.videoImportService,
    this.videoVaultService,
    this.documentPickerRepository,
    this.documentImportService,
    this.documentVaultService,
    this.performanceMonitor = const PerformanceMonitor(),
    this.temporaryFileManager,
    this.temporaryCleaner,
    this.autoLockTimeout = const Duration(seconds: 30),
    this.autoLockNow,
  });

  final ThemeModeStorage? themeModeStorage;
  final SecureStorageService? secureStorageService;
  final OnboardingRepository? onboardingRepository;
  final AuthenticationRepository? authenticationRepository;
  final RecoveryRepository? recoveryRepository;
  final VaultRepository? vaultRepository;
  final VaultSession? vaultSession;
  final ImageLibraryRepository? imageLibraryRepository;
  final ImageImportService? imageImportService;
  final ImageVaultService? imageVaultService;
  final VideoLibraryRepository? videoLibraryRepository;
  final VideoImportService? videoImportService;
  final VideoVaultService? videoVaultService;
  final DocumentPickerRepository? documentPickerRepository;
  final DocumentImportService? documentImportService;
  final DocumentVaultService? documentVaultService;
  final PerformanceMonitor performanceMonitor;
  final TemporaryFileManager? temporaryFileManager;
  final VaultTemporaryCleaner? temporaryCleaner;
  final Duration autoLockTimeout;
  final AutoLockNow? autoLockNow;

  @override
  State<VeyraApp> createState() => _VeyraAppState();
}

final class _VeyraAppState extends State<VeyraApp> {
  VaultDatabase? _ownedVaultDatabase;
  late final VaultRepository _vaultRepository;
  late final VaultSession _vaultSession;
  late final ImageLibraryRepository _imageLibraryRepository;
  late final ImageImportService _imageImportService;
  late final ImageVaultService _imageVaultService;
  late final VideoLibraryRepository _videoLibraryRepository;
  late final VideoImportService _videoImportService;
  late final VideoVaultService _videoVaultService;
  late final DocumentPickerRepository _documentPickerRepository;
  late final DocumentImportService _documentImportService;
  late final DocumentVaultService _documentVaultService;
  late final TemporaryFileManager _temporaryFileManager;
  late final VaultFileStorage _fileStorage;
  late final PerformanceMonitor _performanceMonitor;

  @override
  void initState() {
    super.initState();
    _performanceMonitor = widget.performanceMonitor;
    _vaultSession = widget.vaultSession ?? VaultSession();
    _temporaryFileManager =
        widget.temporaryFileManager ?? PrivateTemporaryFileManager();
    _fileStorage = PrivateVaultFileStorage(
      temporaryFileManager: _temporaryFileManager,
    );
    final VaultRepository? suppliedRepository = widget.vaultRepository;
    if (suppliedRepository != null) {
      _vaultRepository = suppliedRepository;
    } else {
      final VaultDatabase database = VaultDatabase();
      _ownedVaultDatabase = database;
      _vaultRepository = LocalVaultRepository(VaultItemsDao(database));
    }
    _imageLibraryRepository =
        widget.imageLibraryRepository ?? PhotoManagerImageLibraryRepository();
    _imageImportService =
        widget.imageImportService ??
        ImageImportService(
          imageLibrary: _imageLibraryRepository,
          vaultRepository: _vaultRepository,
          fileStorage: _fileStorage,
          vaultSession: _vaultSession,
          performanceMonitor: _performanceMonitor,
        );
    _imageVaultService =
        widget.imageVaultService ??
        ImageVaultService(
          vaultRepository: _vaultRepository,
          fileStorage: _fileStorage,
          vaultSession: _vaultSession,
          imageLibrary: _imageLibraryRepository,
        );
    _videoLibraryRepository =
        widget.videoLibraryRepository ?? PhotoManagerVideoLibraryRepository();
    _videoImportService =
        widget.videoImportService ??
        VideoImportService(
          videoLibrary: _videoLibraryRepository,
          vaultRepository: _vaultRepository,
          fileStorage: _fileStorage,
          vaultSession: _vaultSession,
          performanceMonitor: _performanceMonitor,
        );
    _videoVaultService =
        widget.videoVaultService ??
        VideoVaultService(
          vaultRepository: _vaultRepository,
          fileStorage: _fileStorage,
          vaultSession: _vaultSession,
          videoLibrary: _videoLibraryRepository,
        );
    _documentPickerRepository =
        widget.documentPickerRepository ?? const FilePickerDocumentRepository();
    _documentImportService =
        widget.documentImportService ??
        DocumentImportService(
          documentPicker: _documentPickerRepository,
          vaultRepository: _vaultRepository,
          fileStorage: _fileStorage,
          vaultSession: _vaultSession,
          performanceMonitor: _performanceMonitor,
        );
    _documentVaultService =
        widget.documentVaultService ??
        DocumentVaultService(
          vaultRepository: _vaultRepository,
          fileStorage: _fileStorage,
          vaultSession: _vaultSession,
          exportService: VaultExportService(
            vaultRepository: _vaultRepository,
            fileStorage: _fileStorage,
            vaultSession: _vaultSession,
            destination: const MethodChannelExternalFileDestination(),
          ),
        );
  }

  @override
  void dispose() {
    final VaultDatabase? database = _ownedVaultDatabase;
    if (database != null) {
      unawaited(database.close());
    }
    _vaultSession.lock();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final SecureStorageService secureStorage =
        widget.secureStorageService ?? const FlutterSecureStorageService();
    final ThemeModeStorage themeStorage =
        widget.themeModeStorage ?? secureStorage;
    final OnboardingRepository repository =
        widget.onboardingRepository ??
        SecureOnboardingRepository(storage: secureStorage);
    final AuthenticationRepository authRepository =
        widget.authenticationRepository ??
        SecureAuthenticationRepository(
          storage: secureStorage,
          vaultSession: _vaultSession,
        );
    final RecoveryRepository recovery =
        widget.recoveryRepository ??
        SecureRecoveryRepository(storage: secureStorage);

    return RepositoryProvider<VaultRepository>.value(
      value: _vaultRepository,
      child: RepositoryProvider<ImageLibraryRepository>.value(
        value: _imageLibraryRepository,
        child: RepositoryProvider<VideoLibraryRepository>.value(
          value: _videoLibraryRepository,
          child: RepositoryProvider<ImageImportService>.value(
            value: _imageImportService,
            child: RepositoryProvider<ImageVaultService>.value(
              value: _imageVaultService,
              child: RepositoryProvider<VideoImportService>.value(
                value: _videoImportService,
                child: RepositoryProvider<VideoVaultService>.value(
                  value: _videoVaultService,
                  child: RepositoryProvider<DocumentImportService>.value(
                    value: _documentImportService,
                    child: RepositoryProvider<DocumentVaultService>.value(
                      value: _documentVaultService,
                      child: RepositoryProvider<OnboardingRepository>.value(
                        value: repository,
                        child: RepositoryProvider<RecoveryRepository>.value(
                          value: recovery,
                          child: MultiBlocProvider(
                            providers: <BlocProvider<dynamic>>[
                              BlocProvider<ThemeCubit>(
                                create: (context) {
                                  final ThemeCubit cubit = ThemeCubit(
                                    themeStorage,
                                  );
                                  unawaited(cubit.load());
                                  return cubit;
                                },
                              ),
                              BlocProvider<OnboardingCubit>(
                                create: (context) =>
                                    OnboardingCubit(repository),
                              ),
                              BlocProvider<UnlockCubit>(
                                create: (context) => UnlockCubit(
                                  authRepository,
                                  performanceMonitor: _performanceMonitor,
                                ),
                              ),
                            ],
                            child: _AppView(
                              vaultSession: _vaultSession,
                              temporaryCleaner:
                                  widget.temporaryCleaner ??
                                  _temporaryFileManager,
                              autoLockTimeout: widget.autoLockTimeout,
                              autoLockNow: widget.autoLockNow,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

final class _AppView extends StatefulWidget {
  const _AppView({
    required this.vaultSession,
    required this.temporaryCleaner,
    required this.autoLockTimeout,
    this.autoLockNow,
  });

  final VaultSession vaultSession;
  final VaultTemporaryCleaner temporaryCleaner;
  final Duration autoLockTimeout;
  final AutoLockNow? autoLockNow;

  @override
  State<_AppView> createState() => _AppViewState();
}

final class _AppViewState extends State<_AppView> with WidgetsBindingObserver {
  late final GoRouter _router = AppRouter.create();
  late final VaultAutoLockManager _autoLock = VaultAutoLockManager(
    timeout: widget.autoLockTimeout,
    now: widget.autoLockNow,
    onLock: _lockVault,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        _autoLock.resumed();
      case AppLifecycleState.inactive ||
          AppLifecycleState.hidden ||
          AppLifecycleState.paused:
        _autoLock.movedToBackground();
      case AppLifecycleState.detached:
        unawaited(_autoLock.detached());
    }
  }

  Future<void> _lockVault() async {
    widget.vaultSession.lock();
    if (!mounted) {
      return;
    }
    context.read<UnlockCubit>().resetAfterAutoLock();
    _router.go(AppRoutes.unlockPath);
    try {
      await widget.temporaryCleaner.clear();
    } on Object catch (error, stackTrace) {
      AppErrorHandler.report(error, stackTrace);
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _autoLock.dispose();
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<UnlockCubit, UnlockState>(
      listenWhen: (previous, current) =>
          previous.status != current.status &&
          current.status == UnlockStatus.unlocked,
      listener: (context, state) => _autoLock.activate(),
      child: BlocBuilder<ThemeCubit, ThemeMode>(
        builder: (context, themeMode) {
          return MaterialApp.router(
            title: AppConstants.appName,
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: themeMode,
            themeAnimationDuration: const Duration(milliseconds: 250),
            themeAnimationCurve: Curves.easeInOut,
            routerConfig: _router,
            builder: (context, child) => Listener(
              behavior: HitTestBehavior.translucent,
              onPointerDown: (_) => _autoLock.registerActivity(),
              onPointerMove: (_) => _autoLock.registerActivity(),
              onPointerSignal: (_) => _autoLock.registerActivity(),
              child: child ?? const SizedBox.shrink(),
            ),
          );
        },
      ),
    );
  }
}
