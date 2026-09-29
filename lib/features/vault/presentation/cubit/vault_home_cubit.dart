import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';
import 'package:veyra/features/vault/presentation/cubit/vault_home_state.dart';

final class VaultHomeCubit extends Cubit<VaultHomeState> {
  VaultHomeCubit(this._repository) : super(const VaultHomeState.initial());

  final VaultRepository _repository;

  Future<void> loadCounts() async {
    emit(const VaultHomeState.initial());
    try {
      final List<int> counts = await Future.wait<int>(<Future<int>>[
        _repository.countByType(VaultItemType.image),
        _repository.countByType(VaultItemType.video),
        _repository.countByType(VaultItemType.file),
      ]);
      if (!isClosed) {
        emit(
          VaultHomeState(
            status: VaultHomeStatus.ready,
            imageCount: counts[0],
            videoCount: counts[1],
            fileCount: counts[2],
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      if (!isClosed) {
        emit(
          const VaultHomeState(
            status: VaultHomeStatus.failure,
            imageCount: 0,
            videoCount: 0,
            fileCount: 0,
          ),
        );
        addError(error, stackTrace);
      }
    }
  }
}
