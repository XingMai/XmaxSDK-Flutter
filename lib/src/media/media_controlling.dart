import '../foundation/media/camera/camera_position.dart';
import '../service/realtime/realtime_media_stream.dart';
import '../service/realtime/realtime_video_format.dart';
import '../service/realtime/realtime_video_track.dart';
import 'interaction/interaction_controlling.dart';

abstract interface class MediaControlling implements InteractionControlling {
  RealtimeVideoTrack? get currentTrack;
  RealtimeVideoFormat? get currentVideoFormat;
  bool get hasAudio;

  void setCameraPreviewReadyListener(
    RealtimeCameraPreviewReadyListener? listener,
  );

  Future<RealtimeMediaStream> createLocalCameraStream({
    required RealtimeVideoFormat videoFormat,
    required CameraPosition position,
  });

  Future<void> stopLocalCameraStream();
  Future<void> stopLocalStream();
  Future<RealtimeMediaStream> switchCamera();
  Future<void> setLocalAudioVolume(double volume);
  bool owns(RealtimeMediaStream stream);
}
