import 'package:equatable/equatable.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/videos/domain/entities/gallery_video.dart';

final class ImportedVideo extends Equatable {
  const ImportedVideo({required this.source, required this.item});

  final GalleryVideo source;
  final VaultItem item;

  @override
  List<Object> get props => <Object>[source, item];
}

final class FailedVideoImport extends Equatable {
  const FailedVideoImport({required this.source, required this.error});

  final GalleryVideo source;
  final Object error;

  @override
  List<Object> get props => <Object>[source, error];
}

final class VideoImportResult extends Equatable {
  const VideoImportResult({required this.imported, required this.failed});

  final List<ImportedVideo> imported;
  final List<FailedVideoImport> failed;

  int get total => imported.length + failed.length;

  @override
  List<Object> get props => <Object>[imported, failed];
}
