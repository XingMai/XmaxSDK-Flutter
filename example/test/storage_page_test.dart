import 'dart:io';
import 'dart:typed_data';

import 'package:file_selector_platform_interface/file_selector_platform_interface.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk_example/features/storage/storage_page.dart';
import 'package:xmax_sdk_example/localization/xlab_localization.dart';

void main() {
  testWidgets('translates storage labels and image upload actions', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('en');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    final imageFile = XFile(
      '${Directory.current.path}/android/app/src/main/res/mipmap-mdpi/'
      'ic_launcher.png',
    );
    final originalPlatform = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = _FileSelectorStub(imageFile);
    addTearDown(() => FileSelectorPlatform.instance = originalPlatform);

    await tester.pumpWidget(
      const MaterialApp(home: StoragePage(apiKey: 'test-api-key')),
    );
    expect(find.text('Storage Service'), findsOneWidget);
    expect(find.byTooltip('Back to Home'), findsOneWidget);
    expect(find.text('Upload media with XmaxSDK'), findsOneWidget);
    expect(find.text('File Preview'), findsOneWidget);
    expect(find.text('Tap to select an image or video'), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey<String>('storage-media-preview')),
    );
    await tester.pump();
    expect(find.text('Image'), findsOneWidget);
    expect(find.text('Reselect'), findsOneWidget);
    expect(find.text('Upload & check'), findsOneWidget);
    expect(find.text('Upload'), findsOneWidget);
    expect(
      XLabLocalization.shared.formatCount('storage.upload.progress', 42),
      'Uploading 42%',
    );
  });

  testWidgets('shows an image preview and iOS-aligned metadata after picking', (
    tester,
  ) async {
    tester.binding.platformDispatcher.localeTestValue = const Locale('zh');
    addTearDown(tester.binding.platformDispatcher.clearLocaleTestValue);

    final imageFile = _ReadTrackingXFile(
      '${Directory.current.path}/android/app/src/main/res/mipmap-mdpi/'
      'ic_launcher.png',
    );

    final originalPlatform = FileSelectorPlatform.instance;
    FileSelectorPlatform.instance = _FileSelectorStub(imageFile);
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
    expect(imageFile.readCount, 0);
  });
}

final class _ReadTrackingXFile extends XFile {
  _ReadTrackingXFile(super.path);

  int readCount = 0;

  @override
  Future<Uint8List> readAsBytes() {
    readCount += 1;
    return super.readAsBytes();
  }
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
