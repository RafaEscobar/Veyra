import 'package:veyra/features/files/domain/entities/picked_document.dart';

abstract interface class DocumentPickerRepository {
  Future<List<PickedDocument>> pickDocuments();

  Future<void> clearTemporaryFiles();
}
