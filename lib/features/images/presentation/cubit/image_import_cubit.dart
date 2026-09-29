import 'dart:typed_data';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:veyra/features/images/application/image_import_service.dart';
import 'package:veyra/features/images/application/image_vault_service.dart';
import 'package:veyra/features/images/domain/entities/gallery_image.dart';
import 'package:veyra/features/images/domain/entities/image_import_result.dart';
import 'package:veyra/features/images/presentation/cubit/image_import_state.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';

final class ImageImportCubit extends Cubit<ImageImportState> {
  ImageImportCubit(this._importService, this._vaultService)
    : super(const ImageImportState.initial());

  static const int pageSize = 30;
  final ImageImportService _importService;
  final ImageVaultService _vaultService;

  Future<void> loadCount() => loadInitial();

  Future<void> loadInitial() async {
    emit(state.copyWith(status: ImageImportStatus.loading));
    try {
      final List<VaultItem> items = await _vaultService.loadPage(
        offset: 0,
        limit: pageSize,
      );
      if (!isClosed) {
        emit(
          state.copyWith(
            status: ImageImportStatus.idle,
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

  void toggleNames() => emit(state.copyWith(showNames: !state.showNames));

  Future<ImageImportResult> importImages(List<GalleryImage> images) async {
    emit(
      state.copyWith(
        status: ImageImportStatus.importing,
        completed: 0,
        total: images.length,
      ),
    );
    final ImageImportResult result = await _importService.importImages(
      images,
      onProgress: (completed, total) {
        if (!isClosed) {
          emit(
            state.copyWith(
              status: ImageImportStatus.importing,
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
          status: ImageImportStatus.completed,
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

  Future<Uint8List> loadImage(VaultItem item) {
    return _vaultService.loadImage(item);
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

  Future<Set<String>> deleteOriginals(Iterable<String> sourceIds) {
    return _importService.deleteOriginals(sourceIds);
  }

  void _emitFailure(Object error, StackTrace stackTrace) {
    if (!isClosed) {
      emit(
        state.copyWith(status: ImageImportStatus.failure, isLoadingMore: false),
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
