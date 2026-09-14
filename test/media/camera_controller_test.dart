import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/foundation/media/camera/CameraPosition.dart';
import 'package:xmax_sdk/src/foundation/errors/XmaxError.dart';
import 'package:xmax_sdk/src/foundation/permissions/PermissionManaging.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcEventListener.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcManaging.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcModels.dart';
import 'package:xmax_sdk/src/media/camera/CameraController.dart';
import 'package:xmax_sdk/src/render/video/VideoRenderBinding.dart';
import 'package:xmax_sdk/src/render/video/VideoRenderRegistry.dart';
import 'package:xmax_sdk/src/service/media/MediaServicing.dart';
import 'package:xmax_sdk/src/service/media/MediaService.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeVideoFormat.dart';
import 'package:xmax_sdk/xmax_sdk.dart' show RealtimeModel;

void main() {
  test('preview listener survives an RTC destroy and camera restart', () async {
    final rtc = _FakeRtc();
    final camera = CameraController(
      rtcManager: rtc,
      permissionManager: const _AllowedPermissions(),
      mediaService: const _IdentityMediaService(),
    );
    var readyCount = 0;
    camera.setPreviewReadyListener(() => readyCount += 1);

    await camera.createLocalCameraStream(
      videoFormat: const RealtimeVideoFormat(width: 832, height: 1472, fps: 24),
      position: CameraPosition.front,
    );
    rtc.notifyPreviewReady();
    expect(readyCount, 0);
    _attachPreview(camera);
    expect(readyCount, 1);

    await camera.stopLocalCameraStream();
    await rtc.destroy();
    expect(rtc.previewReadyListener, isNull);

    await camera.createLocalCameraStream(
      videoFormat: const RealtimeVideoFormat(width: 832, height: 1472, fps: 24),
      position: CameraPosition.front,
    );
    _attachPreview(camera);
    expect(readyCount, 1);
    rtc.notifyPreviewReady();

    expect(readyCount, 2);
    await camera.stopLocalCameraStream();
  });

  test(
    'stale capture and preview callbacks cannot ready a new camera',
    () async {
      final rtc = _FakeRtc();
      final camera = CameraController(
        rtcManager: rtc,
        permissionManager: const _AllowedPermissions(),
        mediaService: const _IdentityMediaService(),
      );
      var readyCount = 0;
      camera.setPreviewReadyListener(() => readyCount += 1);

      await camera.createLocalCameraStream(
        videoFormat: const RealtimeVideoFormat(
          width: 832,
          height: 1472,
          fps: 30,
        ),
        position: CameraPosition.front,
      );
      final oldCapture = rtc.previewReadyListener;
      final oldBinding =
          VideoRenderRegistry.handleFor(camera.currentTrack!)!.value
              as LocalVideoRenderBinding;
      await camera.stopLocalCameraStream();

      await camera.createLocalCameraStream(
        videoFormat: const RealtimeVideoFormat(
          width: 832,
          height: 1472,
          fps: 30,
        ),
        position: CameraPosition.front,
      );
      oldCapture?.call();
      oldBinding.onPreviewAttached?.call();
      expect(readyCount, 0);

      rtc.notifyPreviewReady();
      _attachPreview(camera);
      expect(readyCount, 1);
      _attachPreview(camera);
      expect(readyCount, 1);
      await camera.stopLocalCameraStream();
    },
  );

  test(
    'camera switch normalizes RTC failures and preserves position',
    () async {
      final rtc = _FakeRtc();
      final camera = CameraController(
        rtcManager: rtc,
        permissionManager: const _AllowedPermissions(),
        mediaService: const _IdentityMediaService(),
      );
      final stream = await camera.createLocalCameraStream(
        videoFormat: const RealtimeVideoFormat(
          width: 832,
          height: 1472,
          fps: 24,
        ),
        position: CameraPosition.front,
      );
      rtc.switchError = StateError('native switch failed');

      await expectLater(
        camera.switchCamera(),
        throwsA(
          isA<XmaxError>().having(
            (error) => error.code,
            'code',
            XmaxErrorCode.internalError,
          ),
        ),
      );
      expect(stream.videoTrack?.position, CameraPosition.front);
    },
  );

  test('x2.0-pro camera preserves its bucket and 30 fps', () async {
    final rtc = _FakeRtc();
    final camera = CameraController(
      rtcManager: rtc,
      permissionManager: const _AllowedPermissions(),
      mediaService: MediaService(model: RealtimeModel.x2_0_pro),
    );
    final format = RealtimeModel.x2_0_pro.defaultCameraVideoFormat;

    final stream = await camera.createLocalCameraStream(
      videoFormat: format,
      position: CameraPosition.front,
    );

    expect(stream.videoTrack?.videoFormat, format);
    expect(rtc.lastCaptureSize, const Size(1024, 1920));
    expect(rtc.lastCaptureFrameRate, 30);
    await camera.stopLocalCameraStream();
  });

  test('x2.0-pro camera rejects an unsupported input size', () async {
    final rtc = _FakeRtc();
    final camera = CameraController(
      rtcManager: rtc,
      permissionManager: const _AllowedPermissions(),
      mediaService: MediaService(model: RealtimeModel.x2_0_pro),
    );

    await expectLater(
      camera.createLocalCameraStream(
        videoFormat: const RealtimeVideoFormat(
          width: 832,
          height: 1472,
          fps: 24,
        ),
        position: CameraPosition.front,
      ),
      throwsA(
        isA<XmaxError>().having(
          (error) => error.code,
          'code',
          XmaxErrorCode.invalidConfiguration,
        ),
      ),
    );
    expect(rtc.lastCaptureSize, isNull);
  });

  test(
    'camera resize preserves bitrate bounds and encoder preference',
    () async {
      final rtc = _FakeRtc();
      final camera = CameraController(
        rtcManager: rtc,
        permissionManager: const _AllowedPermissions(),
        mediaService: const _ResizingMediaService(),
      );

      final stream = await camera.createLocalCameraStream(
        videoFormat: const RealtimeVideoFormat(
          width: 832,
          height: 1472,
          fps: 30,
          minimumBitrate: 900,
          maximumBitrate: 3000,
          encoderPreference: RealtimeVideoEncoderPreference.maintainFramerate,
        ),
        position: CameraPosition.front,
      );

      expect(
        stream.videoTrack?.videoFormat,
        const RealtimeVideoFormat(
          width: 800,
          height: 1408,
          fps: 30,
          minimumBitrate: 900,
          maximumBitrate: 3000,
          encoderPreference: RealtimeVideoEncoderPreference.maintainFramerate,
        ),
      );
      await camera.stopLocalCameraStream();
    },
  );
}

void _attachPreview(CameraController camera) {
  final binding =
      VideoRenderRegistry.handleFor(camera.currentTrack!)!.value
          as LocalVideoRenderBinding;
  binding.onPreviewAttached?.call();
}

final class _AllowedPermissions implements PermissionManaging {
  const _AllowedPermissions();

  @override
  Future<void> ensureCameraPermission() async {}

  @override
  Future<void> ensureMicrophonePermission() async {}
}

final class _IdentityMediaService implements MediaServicing {
  const _IdentityMediaService();

  @override
  RealtimeModel get model => RealtimeModel.x2_0;

  @override
  Size resolveModelInputSize(Size size) => size;
}

final class _ResizingMediaService implements MediaServicing {
  const _ResizingMediaService();

  @override
  RealtimeModel get model => RealtimeModel.x2_0;

  @override
  Size resolveModelInputSize(Size size) => const Size(800, 1408);
}

final class _FakeRtc implements RtcManaging {
  void Function()? previewReadyListener;
  Object? switchError;
  Size? lastCaptureSize;
  int? lastCaptureFrameRate;

  void notifyPreviewReady() => previewReadyListener?.call();

  @override
  Future<void> destroy() async => previewReadyListener = null;

  @override
  void setCameraPreviewReadyListener(void Function()? listener) {
    previewReadyListener = listener;
  }

  @override
  Future<void> initialize() async {}

  @override
  Future<void> configureVideoEncoding(
    VideoEncodingConfiguration configuration,
  ) async {}

  @override
  Future<void> joinRoom({required RoomJoinConfiguration configuration}) async {}

  @override
  Future<void> leaveRoom() async {}

  @override
  Future<void> publishLocalVideo({required bool publish}) async {}

  @override
  Future<void> sendRoomMessage(String message) async {}

  @override
  void setEventListener(RtcEventListener? listener) {}

  @override
  Future<void> setRemoteAudioVolume({
    required int volume,
    required String streamID,
  }) async {}

  @override
  Future<void> startVideoCapture({
    required int width,
    required int height,
    required int frameRate,
  }) async {
    lastCaptureSize = Size(width.toDouble(), height.toDouble());
    lastCaptureFrameRate = frameRate;
  }

  @override
  Future<void> stopVideoCapture() async {}

  @override
  Future<void> subscribeRemoteAudio({
    required String streamID,
    required bool subscribe,
  }) async {}

  @override
  Future<void> subscribeRemoteVideo({
    required String streamID,
    required bool subscribe,
  }) async {}

  @override
  Future<void> switchCamera({required CameraPosition position}) async {
    final error = switchError;
    if (error != null) throw error;
  }
}
