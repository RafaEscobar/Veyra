import 'package:veyra/core/errors/app_exception.dart';

abstract final class AppErrorMessage {
  static String forError(Object error) {
    return switch (error) {
      WrongPinException() => 'El NIP no es correcto.',
      WrongRecoveryAnswerException() =>
        'La respuesta de seguridad no es correcta.',
      VaultLockedException() || RecoveryLockedException() =>
        'Demasiados intentos. Espera antes de volver a intentarlo.',
      VaultFileNotFoundException() =>
        'No se encontró el archivo protegido de este elemento.',
      VaultFileCorruptedException() =>
        'No se pudo abrir este elemento.\nEl archivo puede estar dañado.',
      StorageFullException() =>
        'No hay espacio suficiente para completar la operación.',
      PermissionDeniedException() =>
        'Veyra no tiene permiso para completar esta operación.',
      EncryptionException() =>
        'No se pudo proteger el archivo. Inténtalo de nuevo.',
      DecryptionException() => 'No se pudo abrir el archivo protegido.',
      ExportException() => 'No se pudo guardar el archivo fuera de la bóveda.',
      ImageTooLargeException() ||
      VideoTooLargeException() ||
      DocumentTooLargeException() => 'El archivo supera el tamaño permitido.',
      InvalidImageTypeException() ||
      InvalidVideoTypeException() ||
      UnsupportedDocumentTypeException() =>
        'El tipo de archivo no es compatible.',
      UnsupportedDocumentPreviewException() =>
        'Este archivo no admite vista previa.',
      _ => 'No se pudo completar la operación. Inténtalo de nuevo.',
    };
  }
}
