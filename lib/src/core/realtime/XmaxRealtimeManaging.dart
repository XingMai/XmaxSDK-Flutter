import '../../foundation/media/camera/CameraPosition.dart';
import '../../service/realtime/RealtimeContext.dart';
import '../../service/realtime/RealtimeError.dart';
import '../../service/realtime/RealtimeMediaStream.dart';
import '../../service/realtime/RealtimeNetworkQuality.dart';
import '../../service/realtime/RealtimePerformanceAlarm.dart';
import '../../service/realtime/RealtimeState.dart';
import '../../service/realtime/RealtimeVideoFormat.dart';
import '../../service/realtime/RealtimeVideoTrack.dart';
import 'RealtimeConfiguration.dart';

abstract interface class XmaxRealtimeManaging {
  RealtimeConfiguration get options;
  Future<RealtimeState> get currentState;

  Future<void> setStateListener(RealtimeStateListener? listener);
  Future<void> setErrorListener(RealtimeErrorListener? listener);
  Future<void> setCameraPreviewReadyListener(
    RealtimeCameraPreviewReadyListener? listener,
  );
  Future<void> setNetworkQualityListener(
    RealtimeNetworkQualityListener? listener,
  );
  Future<void> setPerformanceAlarmListener(
    RealtimePerformanceAlarmListener? listener,
  );
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
