sealed class AppException implements Exception {
  const AppException(this.code, {this.cause});

  final String code;
  final Object? cause;

  @override
  String toString() => 'AppException(code: $code)';
}

sealed class AuthenticationException extends AppException {
  const AuthenticationException(super.code, {super.cause});
}

sealed class VaultException extends AppException {
  const VaultException(super.code, {super.cause});
}

sealed class VaultFileException extends VaultException {
  const VaultFileException(super.code, {super.cause});
}

sealed class ImportException extends VaultException {
  const ImportException(super.code, {super.cause});
}

final class UnexpectedAppException extends AppException {
  const UnexpectedAppException({super.cause}) : super('unexpected_error');
}

final class OnboardingSetupException extends AppException {
  const OnboardingSetupException({super.cause})
    : super('onboarding_setup_failed');
}

final class WrongPinException extends AuthenticationException {
  const WrongPinException({required this.failedAttempts}) : super('wrong_pin');

  final int failedAttempts;
}

final class VaultLockedException extends AuthenticationException {
  const VaultLockedException({required this.lockUntil}) : super('vault_locked');

  final DateTime lockUntil;
}

final class SecurityConfigNotFoundException extends AuthenticationException {
  const SecurityConfigNotFoundException() : super('security_config_not_found');
}

final class WrongRecoveryAnswerException extends AuthenticationException {
  const WrongRecoveryAnswerException({required this.failedAttempts})
    : super('wrong_recovery_answer');

  final int failedAttempts;
}

final class RecoveryLockedException extends AuthenticationException {
  const RecoveryLockedException({required this.lockUntil})
    : super('recovery_locked');

  final DateTime lockUntil;
}

final class RecoverySessionMissingException extends AuthenticationException {
  const RecoverySessionMissingException() : super('recovery_session_missing');
}

base class VaultFileNotFoundException extends VaultFileException {
  const VaultFileNotFoundException() : super('vault_file_not_found');
}

final class VaultSourceFileNotFoundException
    extends VaultFileNotFoundException {
  const VaultSourceFileNotFoundException();
}

base class VaultFileCorruptedException extends VaultFileException {
  const VaultFileCorruptedException({super.cause})
    : super('vault_file_corrupted');
}

final class InvalidEncryptedFileException extends VaultFileCorruptedException {
  const InvalidEncryptedFileException({super.cause});
}

final class StorageFullException extends VaultException {
  const StorageFullException({super.cause}) : super('storage_full');
}

base class PermissionDeniedException extends AppException {
  const PermissionDeniedException({super.cause}) : super('permission_denied');
}

final class PhotoLibraryPermissionDeniedException
    extends PermissionDeniedException {
  const PhotoLibraryPermissionDeniedException();
}

final class EncryptionException extends VaultFileException {
  const EncryptionException({super.cause}) : super('encryption_failed');
}

final class DecryptionException extends VaultFileException {
  const DecryptionException({super.cause}) : super('decryption_failed');
}

base class ExportException extends VaultException {
  const ExportException({super.cause}) : super('export_failed');
}

final class VaultExportVerificationException extends ExportException {
  const VaultExportVerificationException();
}

final class InvalidImageTypeException extends ImportException {
  const InvalidImageTypeException() : super('invalid_image_type');
}

final class ImageTooLargeException extends ImportException {
  const ImageTooLargeException({required this.maximumBytes})
    : super('image_too_large');

  final int maximumBytes;
}

final class ImageImportException extends ImportException {
  const ImageImportException({super.cause}) : super('image_import_failed');
}

final class ImageVaultOperationException extends VaultException {
  const ImageVaultOperationException({super.cause})
    : super('image_vault_operation_failed');
}

final class InvalidVideoTypeException extends ImportException {
  const InvalidVideoTypeException() : super('invalid_video_type');
}

final class VideoTooLargeException extends ImportException {
  const VideoTooLargeException({required this.maximumBytes})
    : super('video_too_large');

  final int maximumBytes;
}

final class VideoImportException extends ImportException {
  const VideoImportException({super.cause}) : super('video_import_failed');
}

final class VideoVaultOperationException extends VaultException {
  const VideoVaultOperationException({super.cause})
    : super('video_vault_operation_failed');
}

final class UnsupportedDocumentTypeException extends ImportException {
  const UnsupportedDocumentTypeException() : super('unsupported_document_type');
}

final class DocumentTooLargeException extends ImportException {
  const DocumentTooLargeException({required this.maximumBytes})
    : super('document_too_large');

  final int maximumBytes;
}

final class DocumentImportException extends ImportException {
  const DocumentImportException({super.cause})
    : super('document_import_failed');
}

final class UnsupportedDocumentPreviewException extends VaultException {
  const UnsupportedDocumentPreviewException()
    : super('unsupported_document_preview');
}
