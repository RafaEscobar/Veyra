import 'package:equatable/equatable.dart';
import 'package:veyra/features/images/domain/entities/image_import_result.dart';
import 'package:veyra/features/vault/domain/entities/vault_folder.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';

enum ImageImportStatus { idle, loading, importing, completed, failure }

final class ImageImportState extends Equatable {
  const ImageImportState({
    required this.status,
    required this.items,
    required this.completed,
    required this.total,
    required this.hasMore,
    required this.isLoadingMore,
    required this.showNames,
    required this.folders,
    this.result,
    this.currentFolder,
  });

  const ImageImportState.initial()
    : status = ImageImportStatus.idle,
      items = const <VaultItem>[],
      completed = 0,
      total = 0,
      hasMore = true,
      isLoadingMore = false,
      showNames = false,
      folders = const <VaultFolder>[],
      result = null,
      currentFolder = null;

  final ImageImportStatus status;
  final List<VaultItem> items;
  final int completed;
  final int total;
  final bool hasMore;
  final bool isLoadingMore;
  final bool showNames;
  final List<VaultFolder> folders;
  final ImageImportResult? result;
  final VaultFolder? currentFolder;

  int get imageCount => items.length;
  double? get progress => total == 0 ? null : completed / total;

  ImageImportState copyWith({
    ImageImportStatus? status,
    List<VaultItem>? items,
    int? completed,
    int? total,
    bool? hasMore,
    bool? isLoadingMore,
    bool? showNames,
    List<VaultFolder>? folders,
    ImageImportResult? result,
    VaultFolder? currentFolder,
    bool clearCurrentFolder = false,
  }) {
    return ImageImportState(
      status: status ?? this.status,
      items: items ?? this.items,
      completed: completed ?? this.completed,
      total: total ?? this.total,
      hasMore: hasMore ?? this.hasMore,
      isLoadingMore: isLoadingMore ?? this.isLoadingMore,
      showNames: showNames ?? this.showNames,
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
    showNames,
    folders,
    result,
    currentFolder,
  ];
}
