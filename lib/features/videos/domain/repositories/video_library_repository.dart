import 'dart:io';
import 'dart:typed_data';

import 'package:veyra/features/images/domain/repositories/image_library_repository.dart';
import 'package:veyra/features/videos/domain/entities/gallery_video.dart';

abstract interface class VideoLibraryRepository {
  Future<ImageLibraryAccess> requestAccess();

  Future<List<GalleryVideo>> loadRecent({
    required int page,
    required int pageSize,
  });

  Future<Uint8List?> loadThumbnail(String id, {required int size});

  Future<File?> loadOriginal(String id);

  Future<void> openSettings();

  Future<void> clearCache();
}

abstract interface class VideoLibraryExporter {
  Future<void> saveToLibrary({
    required File file,
    required String name,
    required DateTime createdAt,
  });
}
