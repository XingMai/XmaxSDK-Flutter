import '../../foundation/media/camera/CameraPosition.dart';
import 'RtcEventListener.dart';
import 'RtcModels.dart';

abstract interface class RtcManaging {
  Future<void> initialize();
  Future<void> destroy();
  Future<void> configureVideoEncoding(VideoEncodingConfiguration configuration);
  Future<void> startVideoCapture({
    required int width,
    required int height,
    required int frameRate,
  });
  Future<void> stopVideoCapture();
  Future<void> switchCamera({required CameraPosition position});
  Future<void> joinRoom({required RoomJoinConfiguration configuration});
  Future<void> leaveRoom();
  Future<void> publishLocalVideo({required bool publish});
  Future<void> subscribeRemoteVideo({
    required String streamID,
    required bool subscribe,
  });
  Future<void> subscribeRemoteAudio({
    required String streamID,
    required bool subscribe,
  });
  Future<void> setRemoteAudioVolume({
    required int volume,
    required String streamID,
  });
  Future<void> sendRoomMessage(String message);
  void setEventListener(RtcEventListener? listener);
  void setCameraPreviewReadyListener(void Function()? listener);
}
