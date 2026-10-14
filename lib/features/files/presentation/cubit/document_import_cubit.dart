import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:veyra/features/files/application/document_import_service.dart';
import 'package:veyra/features/files/application/document_vault_service.dart';
import 'package:veyra/features/files/domain/entities/document_import_result.dart';
import 'package:veyra/features/files/presentation/cubit/document_import_state.dart';
import 'package:veyra/features/vault/domain/entities/vault_folder.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_folder_repository.dart';
import 'package:veyra/features/vault/domain/services/external_file_destination.dart';

final class DocumentImportCubit extends Cubit<DocumentImportState> {
  DocumentImportCubit(
    this._importService,
    this._vaultService, [
    this._folderRepository,
  ]) : super(const DocumentImportState.initial());

  static const int pageSize = 40;
  final DocumentImportService _importService;
  final DocumentVaultService _vaultService;
  final VaultFolderRepository? _folderRepository;

  Future<void> loadItems() => loadInitial();

  Future<void> loadInitial() async {
    emit(state.copyWith(status: DocumentImportStatus.loading));
    try {
      final List<VaultItem> items = await _vaultService.loadPage(
        offset: 0,
        limit: pageSize,
        folderId: state.currentFolder?.id,
      );
      final List<VaultFolder> folders = await _loadFolders();
      if (!isClosed) {
        emit(
          state.copyWith(
            status: DocumentImportStatus.idle,
            items: List<VaultItem>.unmodifiable(items),
            hasMore: items.length == pageSize,
            isLoadingMore: false,
            folders: folders,
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      _emitFailure(error, stackTrace);
    }
  }

  Future<void> loadMore() async {
    if (!state.hasMore || state.isLoadingMore) {
      return;
    }
    emit(state.copyWith(isLoadingMore: true));
    try {
      final List<VaultItem> page = await _vaultService.loadPage(
        offset: state.items.length,
        limit: pageSize,
        folderId: state.currentFolder?.id,
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            items: List<VaultItem>.unmodifiable(<VaultItem>[
              ...state.items,
              ...page,
            ]),
            hasMore: page.length == pageSize,
            isLoadingMore: false,
          ),
        );
      }
    } on Object catch (error, stackTrace) {
      _emitFailure(error, stackTrace);
    }
  }

  Future<DocumentImportResult?> selectAndImport() async {
    emit(
      state.copyWith(
        status: DocumentImportStatus.picking,
        completed: 0,
        total: 0,
      ),
    );
    try {
      final DocumentImportResult? result = await _importService.selectAndImport(
        folderId: state.currentFolder?.id,
        onProgress: (completed, total) {
          if (!isClosed) {
            emit(
              state.copyWith(
                status: DocumentImportStatus.importing,
                completed: completed,
                total: total,
              ),
            );
          }
        },
      );
      if (result == null) {
        if (!isClosed) {
          emit(state.copyWith(status: DocumentImportStatus.idle));
        }
        return null;
      }
      await loadInitial();
      if (!isClosed) {
        emit(
          state.copyWith(
            status: DocumentImportStatus.completed,
            completed: result.total,
            total: result.total,
            result: result,
          ),
        );
      }
      return result;
    } on Object catch (error, stackTrace) {
      _emitFailure(error, stackTrace);
      return null;
    }
  }

  bool canPreview(VaultItem item) => _vaultService.canPreview(item);

  Future<String> loadTextPreview(VaultItem item) {
    return _vaultService.loadTextPreview(item);
  }

  Future<ExternalFileWriteResult?> export(VaultItem item) async {
    emit(state.copyWith(status: DocumentImportStatus.exporting));
    try {
      final ExternalFileWriteResult? result = await _vaultService.export(item);
      if (!isClosed) {
        emit(state.copyWith(status: DocumentImportStatus.idle));
      }
      return result;
    } on Object catch (error, stackTrace) {
      _emitFailure(error, stackTrace);
      rethrow;
    }
  }

  Future<bool> delete(VaultItem item) async {
    emit(state.copyWith(status: DocumentImportStatus.deleting));
    try {
      final bool deleted = await _vaultService.delete(item);
      if (!isClosed) {
        emit(
          state.copyWith(
            status: DocumentImportStatus.idle,
            items: deleted
                ? List<VaultItem>.unmodifiable(
                    state.items.where((candidate) => candidate.id != item.id),
                  )
                : state.items,
          ),
        );
      }
      return deleted;
    } on Object catch (error, stackTrace) {
      _emitFailure(error, stackTrace);
      rethrow;
    }
  }

  Future<void> enterFolder(VaultFolder folder) async {
    emit(state.copyWith(currentFolder: folder, items: const <VaultItem>[]));
    await loadInitial();
  }

  Future<void> leaveFolder() async {
    emit(state.copyWith(clearCurrentFolder: true, items: const <VaultItem>[]));
    await loadInitial();
  }

  Future<void> createFolder(String name) async {
    final VaultFolderRepository? repository = _folderRepository;
    if (repository == null) {
      return;
    }
    final String normalized = name.trim();
    if (normalized.isEmpty || normalized.length > 60) {
      throw ArgumentError('Folder name must contain between 1 and 60 chars.');
    }
    await repository.insertFolder(
      VaultFolder(
        id: const Uuid().v4(),
        name: normalized,
        type: VaultItemType.file,
        createdAt: DateTime.now().toUtc(),
      ),
    );
    await loadInitial();
  }

  Future<void> deleteFolder(VaultFolder folder) async {
    await _folderRepository?.deleteFolder(folder.id);
    if (state.currentFolder?.id == folder.id) {
      emit(state.copyWith(clearCurrentFolder: true));
    }
    await loadInitial();
  }

  Future<void> moveToFolder(VaultItem item, String? folderId) async {
    await _folderRepository?.moveItemToFolder(item.id, folderId);
    await loadInitial();
  }

  Future<List<VaultFolder>> _loadFolders() async {
    return await _folderRepository?.getFoldersByType(VaultItemType.file) ??
        const <VaultFolder>[];
  }

  void _emitFailure(Object error, StackTrace stackTrace) {
    if (!isClosed) {
      emit(
        state.copyWith(
          status: DocumentImportStatus.failure,
          isLoadingMore: false,
        ),
      );
      addError(error, stackTrace);
    }
  }
}
