import 'package:flutter/widgets.dart';

import '../../foundation/errors/XmaxError.dart';
import '../../foundation/logging/XmaxLogger.dart';
import '../../foundation/permissions/PermissionManager.dart';
import '../../foundation/permissions/PermissionManaging.dart';
import '../../foundation/rtc/RtcManaging.dart';
import '../../render/video/VideoRenderBinding.dart';
import '../../render/video/VideoRenderRegistry.dart';
import '../../service/media/MediaService.dart';
import '../../service/media/MediaServicing.dart';
import '../../service/realtime/RealtimeMediaStream.dart';
import '../../service/realtime/RealtimeVideoFormat.dart';
import '../../service/realtime/RealtimeVideoTrack.dart';
import '../../foundation/media/camera/CameraPosition.dart';

final class CameraController {
  CameraController({
    required RtcManaging rtcManager,
    PermissionManaging permissionManager = const PermissionManager(),
    MediaServicing mediaService = const _DefaultMediaService(),
  }) : _rtcManager = rtcManager,
       _permissionManager = permissionManager,
       _mediaService = mediaService;

  static const localVideoTrackID = 'video0';
  static const localStreamID = 'stream-local';

  final RtcManaging _rtcManager;
  final PermissionManaging _permissionManager;
  final MediaServicing _mediaService;
  RealtimeVideoTrack? _activeTrack;
  RealtimeCameraPreviewReadyListener? _previewReadyListener;

  RealtimeVideoTrack? get currentTrack => _activeTrack;

  void setPreviewReadyListener(RealtimeCameraPreviewReadyListener? listener) {
    _previewReadyListener = listener;
    _rtcManager.setCameraPreviewReadyListener(listener);
  }

  Future<RealtimeMediaStream> createLocalCameraStream({
    required RealtimeVideoFormat videoFormat,
    required CameraPosition position,
  }) async {
    if (_activeTrack != null) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message:
            'Stop the current local camera stream before creating another one',
      );
    }

    final format = _resolveVideoFormat(videoFormat);
    final track = createRealtimeVideoTrack(
      id: localVideoTrackID,
      videoFormat: format,
      position: position,
    );

    try {
      await _permissionManager.ensureCameraPermission();

      // RtcManager.destroy() releases its native callback references. Keep the
      // public manager-level listener stable across close() and reinstall it
      // whenever a new RTC camera session starts.
      _rtcManager.setCameraPreviewReadyListener(_previewReadyListener);
      await _rtcManager.switchCamera(position: position);
      await _rtcManager.startVideoCapture(
        width: format.width,
        height: format.height,
        frameRate: format.fps,
      );

      // Register rendering only after capture has started successfully.
      VideoRenderRegistry.register(track, const LocalVideoRenderBinding());
      _activeTrack = track;
      return createRealtimeMediaStream(id: localStreamID, videoTrack: track);
    } catch (error) {
      // Roll back both registry and capture when startup fails midway.
      VideoRenderRegistry.unregister(track);
      try {
        await _rtcManager.stopVideoCapture();
      } catch (cleanupError) {
        XmaxLogger.error(
          category: XmaxLoggerCategory.realtime,
          message:
              '回滚 RTC 相机采集失败 (Failed to Roll Back RTC Camera Capture)\n'
              '└─ 原因：$cleanupError',
        );
      }
      throw XmaxError.from(error);
    }
  }

  Future<void> stopLocalCameraStream() async {
    final track = _activeTrack;
    _activeTrack = null;

    if (track != null) {
      VideoRenderRegistry.unregister(track);
    }

    await _rtcManager.stopVideoCapture();
  }

  Future<RealtimeMediaStream> switchCamera() async {
    final track = _activeTrack;
    final position = track?.position;
    if (track == null || track.videoFormat == null || position == null) {
      throw const XmaxError(
        code: XmaxErrorCode.rtcError,
        message: 'Local camera preview is not started',
      );
    }

    final next = position == CameraPosition.front
        ? CameraPosition.back
        : CameraPosition.front;

    try {
      await _rtcManager.switchCamera(position: next);
      updateRealtimeVideoTrack(track: track, position: next);

      return createRealtimeMediaStream(id: localStreamID, videoTrack: track);
    } catch (error) {
      throw XmaxError.from(error);
    }
  }

  RealtimeVideoFormat _resolveVideoFormat(RealtimeVideoFormat videoFormat) {
    videoFormat.validate();
    final size = _mediaService.resolveModelInputSize(
      Size(videoFormat.width.toDouble(), videoFormat.height.toDouble()),
    );
    final format = RealtimeVideoFormat(
      width: size.width.toInt(),
      height: size.height.toInt(),
      fps: videoFormat.fps,
    );
    format.validate();
    return format;
  }
}

final class _DefaultMediaService implements MediaServicing {
  const _DefaultMediaService();

  @override
  Size resolveModelInputSize(Size size) =>
      MediaService().resolveModelInputSize(size);
}
