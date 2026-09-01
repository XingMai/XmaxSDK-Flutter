import 'dart:io';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk_example/features/storage/storage_page.dart';

void main() {
  testWidgets('shows an image preview and iOS-aligned metadata after picking', (
    tester,
  ) async {
    final imageFile = XFile(
      '${Directory.current.path}/android/app/src/main/res/mipmap-mdpi/'
      'ic_launcher.png',
    );

    final originalPlatform = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = _FileSelectorStub(XFile(imageFile.path));
    addTearDown(() => FileSelectorPlatform.instance = originalPlatform);

    await tester.pumpWidget(
      const MaterialApp(home: StoragePage(apiKey: 'test-api-key')),
    );
    await tester.tap(
      find.byKey(const ValueKey<String>('storage-media-preview')),
    );
    await tester.pump();
    for (var attempt = 0; attempt < 10; attempt += 1) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 20)),
      );
      await tester.pump(const Duration(milliseconds: 20));
      if (find
          .byKey(const ValueKey<String>('storage-image-preview'))
          .evaluate()
          .isNotEmpty) {
        break;
      }
    }
    expect(
      find.byKey(const ValueKey<String>('storage-image-preview')),
      findsOneWidget,
    );
    expect(find.text('文件预览'), findsOneWidget);
    expect(find.text('图片'), findsOneWidget);
    expect(find.text('48 × 48'), findsOneWidget);
    expect(find.text('重新上传'), findsOneWidget);
    expect(find.text('安全检测上传'), findsOneWidget);
    expect(find.text('普通上传'), findsOneWidget);
  });
}

final class _FileSelectorStub extends FileSelectorPlatform {
  _FileSelectorStub(this.file);

  final XFile file;

  @override
  Future<XFile?> openFile({
    List<XTypeGroup>? acceptedTypeGroups,
    String? initialDirectory,
    String? confirmButtonText,
  }) async => file;
}
