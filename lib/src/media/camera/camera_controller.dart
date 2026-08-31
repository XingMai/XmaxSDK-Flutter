import 'package:flutter/widgets.dart';

import '../../foundation/errors/xmax_error.dart';
import '../../foundation/permissions/permission_manager.dart';
import '../../foundation/permissions/permission_managing.dart';
import '../../foundation/rtc/rtc_managing.dart';
import '../../render/video/video_render_binding.dart';
import '../../render/video/video_render_registry.dart';
import '../../service/media/media_service.dart';
import '../../service/media/media_servicing.dart';
import '../../service/realtime/realtime_media_stream.dart';
import '../../service/realtime/realtime_video_format.dart';
import '../../service/realtime/realtime_video_track.dart';
import '../../foundation/media/camera/camera_position.dart';

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

  RealtimeVideoTrack? get currentTrack => _activeTrack;

  void setPreviewReadyListener(RealtimeCameraPreviewReadyListener? listener) {
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
      await _rtcManager.switchCamera(position: position);
      await _rtcManager.startVideoCapture(
        width: format.width,
        height: format.height,
        frameRate: format.fps,
      );
      VideoRenderRegistry.register(track, const LocalVideoRenderBinding());
      _activeTrack = track;
      return createRealtimeMediaStream(id: localStreamID, videoTrack: track);
    } catch (error) {
      VideoRenderRegistry.unregister(track);
      try {
        await _rtcManager.stopVideoCapture();
      } catch (_) {}
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
    await _rtcManager.switchCamera(position: next);
    updateRealtimeVideoTrack(track: track, position: next);
    return createRealtimeMediaStream(id: localStreamID, videoTrack: track);
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
