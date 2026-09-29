import 'package:veyra/features/recovery/domain/entities/recovery_info.dart';

abstract interface class RecoveryRepository {
  Future<RecoveryInfo> getInfo();

  Future<void> verifyAnswer(String normalizedAnswer);

  Future<void> replacePin(String newPin);

  void cancel();
}
