import 'package:equatable/equatable.dart';
import 'package:veyra/features/vault/domain/entities/vault_folder.dart';
import 'package:veyra/features/vault/domain/entities/vault_item.dart';
import 'package:veyra/features/videos/domain/entities/video_import_result.dart';

enum VideoImportStatus {
  idle,
  loading,
  checkingSize,
  importing,
  completed,
  failure,
}

final class VideoImportState extends Equatable {
  const VideoImportState({
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

  const VideoImportState.initial()
    : status = VideoImportStatus.idle,
      items = const <VaultItem>[],
      completed = 0,
      total = 0,
      hasMore = true,
      isLoadingMore = false,
      folders = const <VaultFolder>[],
      result = null,
      currentFolder = null;

  final VideoImportStatus status;
  final List<VaultItem> items;
  final int completed;
  final int total;
  final bool hasMore;
  final bool isLoadingMore;
  final List<VaultFolder> folders;
  final VideoImportResult? result;
  final VaultFolder? currentFolder;

  int get videoCount => items.length;
  double? get progress => total == 0 ? null : completed / total;

  VideoImportState copyWith({
    VideoImportStatus? status,
    List<VaultItem>? items,
    int? completed,
    int? total,
    bool? hasMore,
    bool? isLoadingMore,
    List<VaultFolder>? folders,
    VideoImportResult? result,
    VaultFolder? currentFolder,
    bool clearCurrentFolder = false,
  }) {
    return VideoImportState(
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
