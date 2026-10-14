import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:uuid/uuid.dart';
import 'package:veyra/features/vault/domain/entities/vault_folder.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_folder_repository.dart';
import 'package:veyra/features/videos/application/video_import_service.dart';
import 'package:veyra/features/videos/application/video_vault_service.dart';
import 'package:veyra/features/videos/domain/entities/gallery_video.dart';
import 'package:veyra/features/videos/domain/entities/video_import_result.dart';
import 'package:veyra/features/videos/presentation/cubit/video_import_state.dart';

final class VideoImportCubit extends Cubit<VideoImportState> {
  VideoImportCubit(
    this._importService,
    this._vaultService, [
    this._folderRepository,
  ]) : super(const VideoImportState.initial());

  static const int pageSize = 24;
  final VideoImportService _importService;
  final VideoVaultService _vaultService;
  final VaultFolderRepository? _folderRepository;

  Future<void> loadCount() => loadInitial();

  Future<void> loadInitial() async {
    emit(state.copyWith(status: VideoImportStatus.loading));
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
            status: VideoImportStatus.idle,
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

  Future<List<GalleryVideo>> checkLargeVideos(List<GalleryVideo> videos) async {
    emit(
      state.copyWith(
        status: VideoImportStatus.checkingSize,
        completed: 0,
        total: videos.length,
      ),
    );
    final List<GalleryVideo> largeVideos = await _importService
        .videosRequiringWarning(videos);
    if (!isClosed) {
      emit(
        state.copyWith(status: VideoImportStatus.idle, completed: 0, total: 0),
      );
    }
    return largeVideos;
  }

  Future<void> cancelPreparedImport() => _importService.discardPreparedFiles();

  Future<VideoImportResult> importVideos(List<GalleryVideo> videos) async {
    emit(
      state.copyWith(
        status: VideoImportStatus.importing,
        completed: 0,
        total: videos.length,
      ),
    );
    final VideoImportResult result = await _importService.importVideos(
      videos,
      folderId: state.currentFolder?.id,
      onProgress: (completed, total) {
        if (!isClosed) {
          emit(
            state.copyWith(
              status: VideoImportStatus.importing,
              completed: completed,
              total: total,
            ),
          );
        }
      },
    );
    await loadInitial();
    if (!isClosed) {
      emit(
        state.copyWith(
          status: VideoImportStatus.completed,
          completed: result.total,
          total: result.total,
          result: result,
        ),
      );
    }
    return result;
  }

  Future<Uint8List?> loadThumbnail(VaultItem item) {
    return _vaultService.loadThumbnail(item);
  }

  Future<File> preparePlayback(VaultItem item) {
    return _vaultService.preparePlayback(item);
  }

  Future<void> releasePlayback(File file) {
    return _vaultService.releasePlayback(file);
  }

  Future<bool> delete(VaultItem item) async {
    final bool deleted = await _vaultService.delete(item);
    if (deleted && !isClosed) {
      emit(
        state.copyWith(
          items: List<VaultItem>.unmodifiable(
            state.items.where((candidate) => candidate.id != item.id),
          ),
        ),
      );
    }
    return deleted;
  }

  Future<void> exportAndRemove(VaultItem item) async {
    await _vaultService.exportAndRemove(item);
    if (!isClosed) {
      emit(
        state.copyWith(
          items: List<VaultItem>.unmodifiable(
            state.items.where((candidate) => candidate.id != item.id),
          ),
        ),
      );
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
        type: VaultItemType.video,
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
    return await _folderRepository?.getFoldersByType(VaultItemType.video) ??
        const <VaultFolder>[];
  }

  void _emitFailure(Object error, StackTrace stackTrace) {
    if (!isClosed) {
      emit(
        state.copyWith(status: VideoImportStatus.failure, isLoadingMore: false),
      );
      addError(error, stackTrace);
    }
  }

  @override
  Future<void> close() {
    _vaultService.clearMemoryCache();
    return super.close();
  }
}
