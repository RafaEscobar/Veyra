import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:uuid/uuid.dart';
import 'package:veyra/core/crypto/crypto_service.dart';
import 'package:veyra/core/errors/app_exception.dart';
import 'package:veyra/core/errors/app_exception_mapper.dart';
import 'package:veyra/core/performance/performance_monitor.dart';
import 'package:veyra/core/security/vault_session.dart';
import 'package:veyra/features/files/domain/entities/document_import_result.dart';
import 'package:veyra/features/files/domain/entities/picked_document.dart';
import 'package:veyra/features/files/domain/repositories/document_picker_repository.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/vault/domain/repositories/vault_repository.dart';
import 'package:veyra/features/vault/domain/services/vault_file_storage.dart';

typedef DocumentImportProgress = void Function(int completed, int total);
typedef DocumentIdGenerator = String Function();
typedef DocumentImportUtcNow = DateTime Function();

final class DocumentImportService {
  DocumentImportService({
    required this.documentPicker,
    required this.vaultRepository,
    required this.fileStorage,
    required this.vaultSession,
    CryptoService? cryptoService,
    DocumentIdGenerator? idGenerator,
    DocumentImportUtcNow? utcNow,
    this.performanceMonitor = const PerformanceMonitor(),
    this.maximumDocumentBytes = 250 * 1024 * 1024,
    Map<String, String>? supportedMimeTypes,
  }) : _cryptoService = cryptoService ?? CryptoService(),
       _idGenerator = idGenerator ?? const Uuid().v4,
       _utcNow = utcNow ?? _systemUtcNow,
       supportedMimeTypes = Map<String, String>.unmodifiable(
         supportedMimeTypes ?? _defaultSupportedMimeTypes,
       );

  static const Map<String, String>
  _defaultSupportedMimeTypes = <String, String>{
    'pdf': 'application/pdf',
    'txt': 'text/plain',
    'doc': 'application/msword',
    'docx':
        'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'xls': 'application/vnd.ms-excel',
    'xlsx': 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    'zip': 'application/zip',
  };

  final int maximumDocumentBytes;
  final Map<String, String> supportedMimeTypes;
  final DocumentPickerRepository documentPicker;
  final VaultRepository vaultRepository;
  final VaultFileStorage fileStorage;
  final VaultSession vaultSession;
  final CryptoService _cryptoService;
  final DocumentIdGenerator _idGenerator;
  final PerformanceMonitor performanceMonitor;
  final DocumentImportUtcNow _utcNow;

  Future<DocumentImportResult?> selectAndImport({
    DocumentImportProgress? onProgress,
  }) async {
    try {
      final List<PickedDocument> documents = await documentPicker
          .pickDocuments();
      if (documents.isEmpty) {
        return null;
      }
      return await importDocuments(documents, onProgress: onProgress);
    } finally {
      await documentPicker.clearTemporaryFiles();
    }
  }

  Future<DocumentImportResult> importDocuments(
    List<PickedDocument> documents, {
    DocumentImportProgress? onProgress,
  }) {
    return performanceMonitor.measure(
      PerformanceOperation.documentImport,
      () => _importDocuments(documents, onProgress: onProgress),
    );
  }

  Future<DocumentImportResult> _importDocuments(
    List<PickedDocument> documents, {
    DocumentImportProgress? onProgress,
  }) async {
    final List<ImportedDocument> imported = <ImportedDocument>[];
    final List<FailedDocumentImport> failed = <FailedDocumentImport>[];
    for (int index = 0; index < documents.length; index++) {
      final PickedDocument document = documents[index];
      try {
        imported.add(await _importOne(document));
      } on AppException catch (error) {
        failed.add(FailedDocumentImport(source: document, error: error));
      } on Object catch (error) {
        failed.add(
          FailedDocumentImport(
            source: document,
            error: AppExceptionMapper.map(
              error,
              fallback: (cause) => DocumentImportException(cause: cause),
            ),
          ),
        );
      }
      onProgress?.call(index + 1, documents.length);
    }
    return DocumentImportResult(
      imported: List<ImportedDocument>.unmodifiable(imported),
      failed: List<FailedDocumentImport>.unmodifiable(failed),
    );
  }

  Future<ImportedDocument> _importOne(PickedDocument document) async {
    final String extension = _normalizedExtension(document);
    final String? mimeType = supportedMimeTypes[extension];
    if (mimeType == null) {
      throw const UnsupportedDocumentTypeException();
    }

    final String? sourcePath = document.path;
    if (sourcePath == null) {
      throw const VaultSourceFileNotFoundException();
    }
    final File sourceFile = File(sourcePath);
    if (!await sourceFile.exists()) {
      throw const VaultSourceFileNotFoundException();
    }
    final FileStat metadata = await sourceFile.stat();
    if (metadata.size <= 0) {
      throw const UnsupportedDocumentTypeException();
    }
    if (metadata.size > maximumDocumentBytes) {
      throw DocumentTooLargeException(maximumBytes: maximumDocumentBytes);
    }

    final String id = _idGenerator();
    final String encryptedFileName = '$id.dat';
    final File encryptedFile = await fileStorage.encryptedFile(
      type: VaultItemType.file,
      fileName: encryptedFileName,
    );
    bool metadataSaved = false;
    try {
      await vaultSession.withMasterKey((secretKey) {
        return _cryptoService.encryptFile(
          inputFile: sourceFile,
          outputFile: encryptedFile,
          secretKey: secretKey,
        );
      });
      final VaultItem item = VaultItem(
        id: id,
        originalName: document.name,
        encryptedFileName: encryptedFileName,
        type: VaultItemType.file,
        mimeType: mimeType,
        size: metadata.size,
        createdAt: metadata.modified.toUtc(),
        importedAt: _utcNow(),
      );
      await vaultRepository.insert(item);
      metadataSaved = true;
      return ImportedDocument(source: document, item: item);
    } finally {
      if (!metadataSaved) {
        await fileStorage.deleteIfExists(encryptedFile);
      }
    }
  }

  String _normalizedExtension(PickedDocument document) {
    final String fromName = path
        .extension(document.name)
        .replaceFirst('.', '')
        .trim()
        .toLowerCase();
    if (fromName.isNotEmpty) {
      return fromName;
    }
    return (document.extension ?? '').trim().toLowerCase();
  }
}

DateTime _systemUtcNow() => DateTime.now().toUtc();
