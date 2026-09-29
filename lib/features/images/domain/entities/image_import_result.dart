import 'package:equatable/equatable.dart';
import 'package:veyra/features/images/domain/entities/gallery_image.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';

final class ImportedImage extends Equatable {
  const ImportedImage({required this.source, required this.item});

  final GalleryImage source;
  final VaultItem item;

  @override
  List<Object> get props => <Object>[source, item];
}

final class FailedImageImport extends Equatable {
  const FailedImageImport({required this.source, required this.error});

  final GalleryImage source;
  final Object error;

  @override
  List<Object> get props => <Object>[source, error];
}

final class ImageImportResult extends Equatable {
  const ImageImportResult({required this.imported, required this.failed});

  final List<ImportedImage> imported;
  final List<FailedImageImport> failed;

  int get total => imported.length + failed.length;

  @override
  List<Object> get props => <Object>[imported, failed];
}
