import 'package:file_picker/file_picker.dart';
import 'package:veyra/features/files/domain/entities/picked_document.dart';
import 'package:veyra/features/files/domain/repositories/document_picker_repository.dart';

final class FilePickerDocumentRepository implements DocumentPickerRepository {
  const FilePickerDocumentRepository();

  static const List<String> allowedExtensions = <String>[
    'pdf',
    'txt',
    'doc',
    'docx',
    'xls',
    'xlsx',
    'zip',
  ];

  @override
  Future<List<PickedDocument>> pickDocuments() async {
    final List<PlatformFile> files = await FilePicker.pickFiles(
      dialogTitle: 'Seleccionar archivos',
      type: FileType.custom,
      allowedExtensions: allowedExtensions,
    );
    return List<PickedDocument>.unmodifiable(
      files.map(
        (file) => PickedDocument(
          name: file.name,
          path: file.path,
          extension: file.extension?.toLowerCase(),
        ),
      ),
    );
  }

  @override
  Future<void> clearTemporaryFiles() => FilePicker.clearTemporaryFiles();
}
