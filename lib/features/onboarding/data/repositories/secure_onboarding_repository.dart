import 'package:veyra/core/crypto/onboarding_crypto_service.dart';
import 'package:veyra/core/security/security_config.dart';
import 'package:veyra/core/storage/flutter_secure_storage_service.dart';
import 'package:veyra/core/storage/secure_storage_service.dart';
import 'package:veyra/features/onboarding/domain/repositories/onboarding_repository.dart';

final class SecureOnboardingRepository implements OnboardingRepository {
  SecureOnboardingRepository({
    SecurityConfigStorage? storage,
    OnboardingCryptoService? cryptoService,
  }) : _storage = storage ?? const FlutterSecureStorageService(),
       _cryptoService = cryptoService ?? OnboardingCryptoService();

  final SecurityConfigStorage _storage;
  final OnboardingCryptoService _cryptoService;

  @override
  Future<bool> isCompleted() => _storage.hasSecurityConfig();

  @override
  Future<void> complete({
    required String pin,
    required String normalizedRecoveryAnswer,
    required String securityQuestionId,
  }) async {
    final SecurityConfig config = await _cryptoService.createSecurityConfig(
      pin: pin,
      normalizedRecoveryAnswer: normalizedRecoveryAnswer,
      securityQuestionId: securityQuestionId,
    );
    await _storage.writeSecurityConfig(config);
  }
}
