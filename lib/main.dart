import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:veyra/app/app.dart';
import 'package:veyra/core/errors/app_error_handler.dart';
import 'package:veyra/core/performance/performance_monitor.dart';
import 'package:veyra/core/utils/app_bloc_observer.dart';
import 'package:veyra/features/vault/data/storage/private_temporary_file_manager.dart';

Future<void> main() async {
  await runZonedGuarded<Future<void>>(() async {
    WidgetsFlutterBinding.ensureInitialized();
    AppErrorHandler.initialize();
    Bloc.observer = const AppBlocObserver();
    const PerformanceMonitor performanceMonitor = PerformanceMonitor();
    final PerformanceTrace startupTrace = performanceMonitor.start(
      PerformanceOperation.appStartup,
    );
    final PrivateTemporaryFileManager temporaryFileManager =
        PrivateTemporaryFileManager();
    try {
      await temporaryFileManager.clear();
    } on Object catch (error, stackTrace) {
      AppErrorHandler.report(error, stackTrace);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => startupTrace.finish());
    runApp(
      VeyraApp(
        performanceMonitor: performanceMonitor,
        temporaryFileManager: temporaryFileManager,
      ),
    );
  }, (error, stackTrace) => AppErrorHandler.report(error, stackTrace));
}
