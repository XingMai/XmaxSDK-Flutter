import '../foundation/media/camera/CameraPosition.dart';
import '../service/realtime/RealtimeMediaStream.dart';
import '../service/realtime/RealtimeVideoFormat.dart';
import '../service/realtime/RealtimeVideoTrack.dart';
import 'interaction/InteractionControlling.dart';

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
