import '../../foundation/media/camera/CameraPosition.dart';
import 'RealtimeVideoFormat.dart';

/// 实时视频轨道及其动态元数据。
final class RealtimeVideoTrack {
  RealtimeVideoTrack._({
    required this.id,
    RealtimeVideoFormat? videoFormat,
    CameraPosition? position,
  }) : _videoFormat = videoFormat,
       _position = position;

  final String id;
  RealtimeVideoFormat? _videoFormat;
  CameraPosition? _position;

  RealtimeVideoFormat? get videoFormat => _videoFormat;
  CameraPosition? get position => _position;
}

typedef RealtimeCameraPreviewReadyListener = void Function();

/// Package-internal construction hook. Not exported by `XmaxSDK.dart`.
RealtimeVideoTrack createRealtimeVideoTrack({
  required String id,
  RealtimeVideoFormat? videoFormat,
  CameraPosition? position,
}) =>
    RealtimeVideoTrack._(id: id, videoFormat: videoFormat, position: position);

/// Package-internal metadata hook. Not exported by `XmaxSDK.dart`.
void updateRealtimeVideoTrack({
  required RealtimeVideoTrack track,
  RealtimeVideoFormat? videoFormat,
  CameraPosition? position,
}) {
  if (videoFormat != null) {
    track._videoFormat = videoFormat;
  }
  if (position != null) {
    track._position = position;
  }
}
