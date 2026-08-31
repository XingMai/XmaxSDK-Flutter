import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/foundation/storage/storage_managing.dart';
import 'package:xmax_sdk/src/foundation/storage/storage_models.dart';
import 'package:xmax_sdk/src/service/network/api_servicing.dart';
import 'package:xmax_sdk/src/service/storage/storage_service.dart';
import 'package:xmax_sdk/xmax_sdk.dart';

void main() {
  late _FakeApiService apiService;
  late _FakeStorageManager storageManager;
  late StorageService service;

  setUp(() {
    apiService = _FakeApiService();
    storageManager = _FakeStorageManager();
    service = StorageService(
      apiService: apiService,
      storageManager: storageManager,
      dateGenerator: () => DateTime.fromMillisecondsSinceEpoch(1234),
      identifierGenerator: () => 'ABC-123',
    );
  });

  test(
    'uploadImage fetches STS and builds iOS-compatible object key',
    () async {
      final result = await service.uploadImage(
        data: Uint8List.fromList(<int>[1, 2, 3]),
        fileName: ' look @ 1.png ',
        contentType: 'image/png',
      );

      expect(apiService.paths, <String>['/cos/sts']);
      expect(storageManager.objectKey, 'uploads/1234_abc-123_look_1.png');
      expect(storageManager.contentType, 'image/png');
      expect(result.objectKey, storageManager.objectKey);
    },
  );

  test('uploadImageWithSafetyCheck returns checked URL', () async {
    apiService.safetyPayload = <String, dynamic>{
      'safe': true,
      'url': 'https://safe.example/result.png',
    };

    final result = await service.uploadImageWithSafetyCheck(
      data: Uint8List.fromList(<int>[1]),
      fileName: 'image.png',
      contentType: 'image/png',
    );

    expect(result.url, Uri.parse('https://safe.example/result.png'));
    expect(apiService.paths, <String>['/cos/sts', '/cos/image/check']);
  });

  test('uploadImageWithSafetyCheck maps unsafe image', () async {
    apiService.safetyPayload = <String, dynamic>{'safe': false};

    await expectLater(
      service.uploadImageWithSafetyCheck(
        data: Uint8List.fromList(<int>[1]),
        fileName: 'image.png',
        contentType: 'image/png',
      ),
      throwsA(
        isA<XmaxError>().having(
          (error) => error.code,
          'code',
          XmaxErrorCode.unsafeImage,
        ),
      ),
    );
  });

  test('upload validates source, content type, and file name', () async {
    await expectLater(
      service.uploadVideo(
        data: Uint8List(0),
        fileName: 'video.mp4',
        contentType: 'video/mp4',
      ),
      throwsA(isA<XmaxError>()),
    );
    await expectLater(
      service.uploadImage(
        data: Uint8List.fromList(<int>[1]),
        fileName: 'image.png',
        contentType: 'video/mp4',
      ),
      throwsA(
        isA<XmaxError>().having(
          (error) => error.code,
          'code',
          XmaxErrorCode.invalidConfiguration,
        ),
      ),
    );
  });

  test('download validates remote and destination URLs', () async {
    await expectLater(
      service.downloadImage(
        remoteURL: Uri.parse('file:///remote.png'),
        destinationURL: Uri.file('/tmp/result.png'),
      ),
      throwsA(isA<XmaxError>()),
    );
    await expectLater(
      service.downloadImage(
        remoteURL: Uri.parse('https://example.com/image.png'),
        destinationURL: Uri.parse('https://example.com/result.png'),
      ),
      throwsA(isA<XmaxError>()),
    );
  });
}

final class _FakeApiService implements ApiServicing {
  final List<String> paths = <String>[];
  Map<String, dynamic> safetyPayload = <String, dynamic>{
    'safe': true,
    'url': 'https://safe.example/image.png',
  };

  @override
  Future<T> request<T>(
    ApiMethod method, {
    required String path,
    Object? body,
    required T Function(Object? json) decode,
  }) async {
    paths.add(path);
    if (path == '/cos/sts') {
      return decode(<String, dynamic>{
        'bucket': 'bucket-123',
        'region': 'ap-shanghai',
        'endpoint': '',
        'prefix': 'uploads/',
        'credentials': <String, dynamic>{
          'accessKeyId': 'id',
          'secretAccessKey': 'secret',
          'sessionToken': 'token',
        },
      });
    }
    return decode(safetyPayload);
  }
}

final class _FakeStorageManager implements StorageManaging {
  String objectKey = '';
  String contentType = '';

  @override
  Future<StoredFile> upload({
    required StorageUploadSource source,
    required String objectKey,
    required String contentType,
    required StorageConfiguration configuration,
    StorageProgressListener? progress,
  }) async {
    this.objectKey = objectKey;
    this.contentType = contentType;
    progress?.call(3, 3);
    return StoredFile(
      url: Uri.parse('https://bucket.example/$objectKey'),
      objectKey: objectKey,
      etag: 'etag',
    );
  }

  @override
  Future<DownloadedFile> download({
    required Uri remoteURL,
    required Uri destinationURL,
    StorageProgressListener? progress,
  }) async => DownloadedFile(fileURL: destinationURL, byteCount: 10);
}
