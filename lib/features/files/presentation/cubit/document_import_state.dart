import 'package:equatable/equatable.dart';
import 'package:veyra/features/files/domain/entities/document_import_result.dart';
import 'package:veyra/features/vault/domain/entities/vault_folder.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';

enum DocumentImportStatus {
  idle,
  loading,
  picking,
  importing,
  exporting,
  deleting,
  completed,
  failure,
}

final class DocumentImportState extends Equatable {
  const DocumentImportState({
    required this.status,
    required this.items,
    required this.completed,
    required this.total,
    required this.hasMore,
    required this.isLoadingMore,
    required this.folders,
    this.result,
    this.currentFolder,
  });

  const DocumentImportState.initial()
    : status = DocumentImportStatus.idle,
      items = const <VaultItem>[],
      completed = 0,
      total = 0,
      hasMore = true,
      isLoadingMore = false,
      folders = const <VaultFolder>[],
      result = null,
      currentFolder = null;

  final DocumentImportStatus status;
  final List<VaultItem> items;
  final int completed;
  final int total;
  final bool hasMore;
  final bool isLoadingMore;
  final List<VaultFolder> folders;
  final DocumentImportResult? result;
  final VaultFolder? currentFolder;

  double? get progress => total == 0 ? null : completed / total;

  DocumentImportState copyWith({
    DocumentImportStatus? status,
    List<VaultItem>? items,
    int? completed,
    int? total,
    bool? hasMore,
    bool? isLoadingMore,
    List<VaultFolder>? folders,
    DocumentImportResult? result,
    VaultFolder? currentFolder,
    bool clearCurrentFolder = false,
  }) {
    return DocumentImportState(
      status: status ?? this.status,
      items: items ?? this.items,
      completed: completed ?? this.completed,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      folders: folders ?? this.folders,
      result: result,
      currentFolder: clearCurrentFolder
          ? null
          : currentFolder ?? this.currentFolder,
    );
  }

  @override
  List<Object?> get props => <Object?>[
    status,
    items,
    completed,
    total,
    hasMore,
    isLoadingMore,
    folders,
    result,
    currentFolder,
  ];
}
