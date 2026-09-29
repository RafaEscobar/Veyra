import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:veyra/features/images/domain/entities/gallery_image.dart';
import 'package:veyra/features/images/domain/repositories/image_library_repository.dart';
import 'package:veyra/features/images/presentation/pages/image_asset_picker_screen.dart';

void main() {
  testWidgets('selects multiple images and returns them', (
    WidgetTester tester,
  ) async {
    final FakeImageLibraryRepository repository = FakeImageLibraryRepository(
      images: <GalleryImage>[
        _image('one', 'Uno.jpg'),
        _image('two', 'Dos.jpg'),
      ],
    );
    List<GalleryImage>? selected;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const ValueKey<String>('open-picker'),
              onPressed: () async {
                selected = await Navigator.of(context).push<List<GalleryImage>>(
                  MaterialPageRoute<List<GalleryImage>>(
                    builder: (context) =>
                        ImageAssetPickerScreen(repository: repository),
                  ),
                );
              },
              child: const Text('Abrir'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey<String>('open-picker')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey<String>('select-image-one')));
    await tester.tap(find.byKey(const ValueKey<String>('select-image-two')));
    await tester.pump();

    expect(find.text('Agregar (2)'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey<String>('confirm-image-selection')),
    );
    await tester.pumpAndSettle();

    expect(selected, repository.images);
    expect(repository.cacheCleared, isFalse);
  });

  testWidgets('shows a settings action when access is denied', (
    WidgetTester tester,
  ) async {
    final FakeImageLibraryRepository repository = FakeImageLibraryRepository(
      images: <GalleryImage>[],
      access: ImageLibraryAccess.denied,
    );
    await tester.pumpWidget(
      MaterialApp(home: ImageAssetPickerScreen(repository: repository)),
    );
    await tester.pumpAndSettle();

    expect(
      find.text('Veyra necesita acceso a tus imágenes para seleccionarlas.'),
      findsOneWidget,
    );
    await tester.tap(find.byKey(const ValueKey<String>('open-photo-settings')));
    await tester.pump();

    expect(repository.settingsOpened, isTrue);
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    expect(repository.cacheCleared, isTrue);
  });
}

GalleryImage _image(String id, String name) {
  return GalleryImage(
    id: id,
    name: name,
    createdAt: DateTime.utc(2026),
    mimeType: 'image/jpeg',
  );
}

final class FakeImageLibraryRepository implements ImageLibraryRepository {
  FakeImageLibraryRepository({
    required this.images,
    this.access = ImageLibraryAccess.full,
  });

  final List<GalleryImage> images;
  final ImageLibraryAccess access;
  bool settingsOpened = false;
  bool cacheCleared = false;

  @override
  Future<void> clearCache() async {
    cacheCleared = true;
  }

  @override
  Future<Set<String>> deleteOriginals(Iterable<String> ids) async {
    return ids.toSet();
  }

  @override
  Future<File?> loadOriginal(String id) async => null;

  @override
  Future<List<GalleryImage>> loadRecent({
    required int page,
    required int pageSize,
  }) async {
    return page == 0 ? images : <GalleryImage>[];
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
