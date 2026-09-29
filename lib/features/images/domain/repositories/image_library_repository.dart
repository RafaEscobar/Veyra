import 'dart:io';
import 'dart:typed_data';

import 'package:veyra/features/images/domain/entities/gallery_image.dart';

enum ImageLibraryAccess { full, limited, denied }

abstract interface class ImageLibraryRepository {
  Future<ImageLibraryAccess> requestAccess();

  Future<List<GalleryImage>> loadRecent({
    required int page,
    required int pageSize,
  });

  Future<Uint8List?> loadThumbnail(String id, {required int size});

  Future<File?> loadOriginal(String id);

  Future<Set<String>> deleteOriginals(Iterable<String> ids);

  Future<void> openSettings();

  Future<void> clearCache();
}

abstract interface class ImageLibraryExporter {
  Future<void> saveToLibrary({
    required File file,
    required String name,
    required DateTime createdAt,
  });
}
