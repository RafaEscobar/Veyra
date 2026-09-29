import 'package:equatable/equatable.dart';

enum VaultHomeStatus { loading, ready, failure }

final class VaultHomeState extends Equatable {
  const VaultHomeState({
    required this.status,
    required this.imageCount,
    required this.videoCount,
    required this.fileCount,
  });

  const VaultHomeState.initial()
    : status = VaultHomeStatus.loading,
      imageCount = 0,
      videoCount = 0,
      fileCount = 0;

  final VaultHomeStatus status;
  final int imageCount;
  final int videoCount;
  final int fileCount;

  @override
  List<Object> get props => <Object>[status, imageCount, videoCount, fileCount];
}
