import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/videos/application/video_import_service.dart';
import 'package:veyra/features/videos/application/video_vault_service.dart';
import 'package:veyra/features/videos/domain/entities/gallery_video.dart';
import 'package:veyra/features/videos/domain/entities/video_import_result.dart';
import 'package:veyra/features/videos/presentation/cubit/video_import_state.dart';

final class VideoImportCubit extends Cubit<VideoImportState> {
  VideoImportCubit(this._importService, this._vaultService)
    : super(const VideoImportState.initial());

  static const int pageSize = 24;
  final VideoImportService _importService;
  final VideoVaultService _vaultService;

  Future<void> loadCount() => loadInitial();

  Future<void> loadInitial() async {
    emit(state.copyWith(status: VideoImportStatus.loading));
    try {
      final List<VaultItem> items = await _vaultService.loadPage(
        offset: 0,
        limit: pageSize,
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            status: VideoImportStatus.idle,
            items: List<VaultItem>.unmodifiable(items),
            hasMore: items.length == pageSize,
            isLoadingMore: false,
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
