import 'dart:io';
import 'dart:typed_data';

import 'package:photo_manager/photo_manager.dart';
import 'package:veyra/features/images/domain/entities/gallery_image.dart';
import 'package:veyra/features/images/domain/repositories/image_library_repository.dart';

final class PhotoManagerImageLibraryRepository
    implements ImageLibraryRepository, ImageLibraryExporter {
  static const int _maximumCachedAssets = 180;
  static const PermissionRequestOption _permissionOption =
      PermissionRequestOption(
        androidPermission: AndroidPermission(
          type: RequestType.image,
          mediaLocation: false,
        ),
      );

  final Map<String, AssetEntity> _assets = <String, AssetEntity>{};

  @override
  Future<ImageLibraryAccess> requestAccess() async {
    final PermissionState state = await PhotoManager.requestPermissionExtend(
      requestOption: _permissionOption,
    );
    if (state.isAuth) {
      return ImageLibraryAccess.full;
    }
    if (state.hasAccess) {
      return ImageLibraryAccess.limited;
    }
    return ImageLibraryAccess.denied;
  }

  @override
  Future<List<GalleryImage>> loadRecent({
    required int page,
    required int pageSize,
  }) async {
    final List<AssetEntity> assets = await PhotoManager.getAssetListPaged(
      page: page,
      pageCount: pageSize,
      type: RequestType.image,
    );
    for (final AssetEntity asset in assets) {
      _assets[asset.id] = asset;
    }
    _trimAssetCache();
    return Future.wait<GalleryImage>(assets.map(_toGalleryImage));
  }

  @override
  Future<Uint8List?> loadThumbnail(String id, {required int size}) async {
    final AssetEntity? asset = await _findAsset(id);
    return asset?.thumbnailDataWithSize(
      ThumbnailSize.square(size),
      quality: 80,
    );
  }

  @override
  Future<File?> loadOriginal(String id) async {
    final AssetEntity? asset = await _findAsset(id);
    return asset?.originFile;
  }

  @override
  Future<Set<String>> deleteOriginals(Iterable<String> ids) async {
    final List<String> requestedIds = ids.toSet().toList(growable: false);
    if (requestedIds.isEmpty) {
      return <String>{};
    }
    final List<String> deletedIds = await PhotoManager.editor.deleteWithIds(
      requestedIds,
    );
    for (final String id in deletedIds) {
      _assets.remove(id);
    }
    return deletedIds.toSet();
  }

  @override
  Future<void> saveToLibrary({
    required File file,
    required String name,
    required DateTime createdAt,
  }) async {
    await PhotoManager.editor.saveImageWithPath(
      file.path,
      title: name,
      creationDate: createdAt,
    );
  }

  @override
  Future<void> openSettings() => PhotoManager.openSetting();

  @override
  Future<void> clearCache() async {
    _assets.clear();
    await PhotoManager.clearFileCache();
  }

  Future<GalleryImage> _toGalleryImage(AssetEntity asset) async {
    String name = asset.title ?? '';
    if (name.isEmpty) {
      name = await asset.titleAsync;
    }
    final String? mimeType = asset.mimeType ?? await asset.mimeTypeAsync;
    return GalleryImage(
      id: asset.id,
      name: name.isEmpty ? 'Imagen' : name,
      createdAt: asset.createDateTime,
      mimeType: mimeType,
    );
  }

  Future<AssetEntity?> _findAsset(String id) async {
    return _assets[id] ?? await AssetEntity.fromId(id);
  }

  void _trimAssetCache() {
    while (_assets.length > _maximumCachedAssets) {
      _assets.remove(_assets.keys.first);
    }
  }
}
