import 'package:equatable/equatable.dart';
import 'package:veyra/features/files/domain/entities/picked_document.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';

final class ImportedDocument extends Equatable {
  const ImportedDocument({required this.source, required this.item});

  final PickedDocument source;
  final VaultItem item;

  @override
  List<Object> get props => <Object>[source, item];
}

final class FailedDocumentImport extends Equatable {
  const FailedDocumentImport({required this.source, required this.error});

  final PickedDocument source;
  final Object error;

  @override
  List<Object> get props => <Object>[source, error];
}

final class DocumentImportResult extends Equatable {
  const DocumentImportResult({required this.imported, required this.failed});

  final List<ImportedDocument> imported;
  final List<FailedDocumentImport> failed;

  int get total => imported.length + failed.length;

  @override
  List<Object> get props => <Object>[imported, failed];
}
