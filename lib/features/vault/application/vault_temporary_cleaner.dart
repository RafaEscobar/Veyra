import 'package:veyra/features/vault/data/storage/private_temporary_file_manager.dart';
import 'package:veyra/features/vault/domain/services/temporary_file_manager.dart';

export 'package:veyra/features/vault/domain/services/temporary_file_manager.dart'
    show VaultTemporaryCleaner;

final class PrivateVaultTemporaryCleaner implements VaultTemporaryCleaner {
  PrivateVaultTemporaryCleaner({TemporaryDirectoryProvider? directoryProvider})
    : _manager = PrivateTemporaryFileManager(
        directoryProvider: directoryProvider,
      );

  final TemporaryFileManager _manager;

  @override
  Future<void> clear() => _manager.clear();
}
