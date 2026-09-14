import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:tencentcloud_cos_sdk_plugin_nobeacon/cos.dart';
import 'package:tencentcloud_cos_sdk_plugin_nobeacon/pigeon.dart';
import 'package:xmax_sdk/src/foundation/storage/StorageManager.dart';
import 'package:xmax_sdk/src/foundation/storage/StorageModels.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
    'concurrent uploads initialize signing before registering simple PUT',
    () async {
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      const initialize = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.CosApi.initWithSessionCredential',
        CosApi.codec,
      );
      const register = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.CosApi.registerTransferManger',
        CosApi.codec,
      );
      const upload = BasicMessageChannel<Object?>(
        'dev.flutter.pigeon.CosTransferApi.upload',
        CosTransferApi.codec,
      );
      final initialized = Completer<void>();
      final initStarted = Completer<void>();
      var initCount = 0;
      var registerCount = 0;
      final requests = <List<Object?>>[];

      messenger.setMockDecodedMessageHandler<Object?>(initialize, (_) async {
        initCount += 1;
        initStarted.complete();
        await initialized.future;
        return <Object?>[null];
      });
      messenger.setMockDecodedMessageHandler<Object?>(register, (
        message,
      ) async {
        expect(initialized.isCompleted, isTrue);
        registerCount += 1;
        final args = message! as List<Object?>;
        final config = args[2]! as TransferConfig;
        expect(config.forceSimpleUpload, isTrue);
        expect(config.divisionForUpload, 0x7FFFFFFFFFFFFFFF);
        return <Object?>[args[0]];
      });
      messenger.setMockDecodedMessageHandler<Object?>(upload, (message) async {
        final args = message! as List<Object?>;
        requests.add(args);
        expect(args[6], isNull, reason: 'Never resume a multipart upload');
        final credential = args[16]! as SessionQCloudCredentials;
        expect(
          credential.token,
          args[1] == 'image-123' ? 'image-token' : 'video-token',
        );
        final transfer = Cos().getTransferManger(args[0]! as String);
        transfer.runProgressCallBack(args[14]! as int, 10, 10);
        transfer.runResultSuccessCallBack(args[12]! as int, <String, String>{
          'etag': 'test-etag',
        }, null);
        return <Object?>['test-upload'];
      });
      addTearDown(() {
        messenger.setMockDecodedMessageHandler<Object?>(initialize, null);
        messenger.setMockDecodedMessageHandler<Object?>(register, null);
        messenger.setMockDecodedMessageHandler<Object?>(upload, null);
      });

      final directory = await Directory.systemTemp.createTemp(
        'xmax-upload-test-',
      );
      addTearDown(() => directory.delete(recursive: true));
      final file = File('${directory.path}/video.mp4');
      await file.writeAsBytes(<int>[1, 2, 3]);
      final client = HttpClient();
      addTearDown(() => client.close(force: true));
      final manager = StorageManager(httpClient: client);
      final progress = <int>[];

      StorageConfiguration configuration(String media) => StorageConfiguration(
        bucket: '$media-123',
        region: 'ap-shanghai',
        endpoint: '',
        credential: StorageCredential(
          accessKeyID: '$media-id',
          secretAccessKey: '$media-secret',
          sessionToken: '$media-token',
        ),
      );

      final image = manager.upload(
        source: StorageDataUploadSource(Uint8List(9 * 1024 * 1024)),
        objectKey: 'image.jpg',
        contentType: 'image/jpeg',
        configuration: configuration('image'),
        progress: (completed, _) => progress.add(completed),
      );
      final video = manager.upload(
        source: StorageFileUploadSource(file.uri),
        objectKey: 'video.mp4',
        contentType: 'video/mp4',
        configuration: configuration('video'),
        progress: (completed, _) => progress.add(completed),
      );
      await initStarted.future;
      expect(initCount, 1);
      expect(registerCount, 0);
      expect(requests, isEmpty);
      initialized.complete();

      final results = await Future.wait(<Future<StoredFile>>[image, video]);
      expect(registerCount, 2);
      expect(requests, hasLength(2));
      final imageRequest = requests.singleWhere(
        (args) => args[1] == 'image-123',
      );
      final videoRequest = requests.singleWhere(
        (args) => args[1] == 'video-123',
      );
      expect((imageRequest[5]! as Uint8List).length, 9 * 1024 * 1024);
      expect(videoRequest[4], file.path);
      expect(videoRequest[5], isNull, reason: 'Video stays file-backed');
      expect(progress, <int>[10, 10]);
      expect(results.map((result) => result.etag), everyElement('test-etag'));
    },
  );
}
