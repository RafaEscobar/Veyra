import 'package:veyra/features/authentication/domain/entities/auth_lock_state.dart';

abstract interface class AuthenticationRepository {
  Future<AuthLockState> getLockState();

  Future<void> unlock(String pin);
}
