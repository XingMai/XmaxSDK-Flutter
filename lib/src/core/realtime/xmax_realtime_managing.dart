import '../../foundation/media/camera/camera_position.dart';
import '../../service/realtime/realtime_context.dart';
import '../../service/realtime/realtime_error.dart';
import '../../service/realtime/realtime_media_stream.dart';
import '../../service/realtime/realtime_network_quality.dart';
import '../../service/realtime/realtime_performance_alarm.dart';
import '../../service/realtime/realtime_state.dart';
import '../../service/realtime/realtime_video_format.dart';
import '../../service/realtime/realtime_video_track.dart';
import 'realtime_configuration.dart';

abstract interface class XmaxRealtimeManaging {
  RealtimeConfiguration get options;
  RealtimeState get currentState;

  void setStateListener(RealtimeStateListener? listener);
  void setErrorListener(RealtimeErrorListener? listener);
  void setCameraPreviewReadyListener(
    RealtimeCameraPreviewReadyListener? listener,
  );
  void setNetworkQualityListener(RealtimeNetworkQualityListener? listener);
  void setPerformanceAlarmListener(RealtimePerformanceAlarmListener? listener);
  Future<void> setLocalAudioVolume(double volume);
  Future<void> setRemoteAudioVolume(double volume);
  Future<RealtimeMediaStream> createLocalCameraStream({
    required RealtimeVideoFormat videoFormat,
    CameraPosition position = CameraPosition.front,
  });
  Future<void> stopLocalCameraStream();
  Future<RealtimeMediaStream> switchCamera();
  Future<RealtimeMediaStream> connect({
    required RealtimeMediaStream localStream,
  });
  Future<void> disconnect();
  Future<void> close();

  /// 开始或更新生成。传入 [localStream] 时按需连接，并返回远端流；
  /// 已连接时可省略 [localStream]，返回值为 `null`。
  Future<RealtimeMediaStream?> startGeneration({
    RealtimeMediaStream? localStream,
    RealtimeContext? context,
  });

  Future<void> stopGeneration();
}
