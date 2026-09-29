import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:veyra/core/errors/app_error_handler.dart';

final class AppBlocObserver extends BlocObserver {
  const AppBlocObserver();

  @override
  void onError(BlocBase<Object?> bloc, Object error, StackTrace stackTrace) {
    AppErrorHandler.report(error, stackTrace);
    super.onError(bloc, error, stackTrace);
  }
}
