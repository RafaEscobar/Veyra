import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/features/images/domain/repositories/image_library_repository.dart';
import 'package:veyra/features/videos/domain/entities/gallery_video.dart';
import 'package:veyra/features/videos/domain/repositories/video_library_repository.dart';
import 'package:veyra/features/videos/presentation/pages/video_asset_picker_screen.dart';

void main() {
  testWidgets('selects multiple videos and returns them', (
    WidgetTester tester,
  ) async {
    final FakeVideoLibraryRepository repository = FakeVideoLibraryRepository(
      videos: <GalleryVideo>[
        _video('one', 'Uno.mp4'),
        _video('two', 'Dos.mp4'),
      ],
    );
    List<GalleryVideo>? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const ValueKey<String>('open-video-picker'),
              onPressed: () async {
                selected = await Navigator.of(context).push<List<GalleryVideo>>(
                  MaterialPageRoute<List<GalleryVideo>>(
                    builder: (context) =>
                        VideoAssetPickerScreen(repository: repository),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('open-video-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('select-video-one')));
    await tester.tap(find.byKey(const ValueKey<String>('select-video-two')));
    await tester.pump();

    expect(find.text('Agregar (2)'), findsOneWidget);
    expect(find.text('1:05'), findsNWidgets(2));
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-video-selection')),
    );
    await tester.pumpAndSettle();

    expect(selected, repository.videos);
    expect(repository.cacheCleared, isFalse);
  });

  testWidgets('offers settings when video access is denied', (
    WidgetTester tester,
  ) async {
    final FakeVideoLibraryRepository repository = FakeVideoLibraryRepository(
      videos: <GalleryVideo>[],
      access: ImageLibraryAccess.denied,
    );
    await tester.pumpWidget(
      MaterialApp(home: VideoAssetPickerScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Veyra necesita acceso a tus videos para seleccionarlos.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('open-video-settings')));
    await tester.pump();
    expect(repository.settingsOpened, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(repository.cacheCleared, isTrue);
  });
}

GalleryVideo _video(String id, String name) {
  return GalleryVideo(
    id: id,
    name: name,
    createdAt: DateTime.utc(2026),
    duration: const Duration(seconds: 65),
    mimeType: 'video/mp4',
  );
}

final class FakeVideoLibraryRepository implements VideoLibraryRepository {
  FakeVideoLibraryRepository({
    required this.videos,
    this.access = ImageLibraryAccess.full,
  });

  final List<GalleryVideo> videos;
  final ImageLibraryAccess access;
  bool settingsOpened = false;
  bool cacheCleared = false;

  @override
  Future<void> clearCache() async {
    cacheCleared = true;
  }

  @override
  Future<File?> loadOriginal(String id) async => null;

  @override
  Future<List<GalleryVideo>> loadRecent({
    required int page,
    required int pageSize,
  }) async {
    return page == 0 ? videos : <GalleryVideo>[];
  }

  @override
  Future<Uint8List?> loadThumbnail(String id, {required int size}) async {
    return null;
  }

  @override
  Future<void> openSettings() async {
    settingsOpened = true;
  }

  @override
  Future<ImageLibraryAccess> requestAccess() async => access;
}
