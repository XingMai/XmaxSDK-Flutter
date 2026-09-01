import '../service/realtime/RealtimeContext.dart';
import '../service/realtime/RealtimeNetworkQuality.dart';
import '../service/realtime/RealtimePerformanceAlarm.dart';
import '../service/realtime/RealtimePoint.dart';
import '../service/realtime/RealtimeSession.dart';
import '../service/realtime/RealtimeVideoFormat.dart';

abstract interface class StreamControlling {
  bool get hasGenerationTask;
  Future<void> setVideoEncoderConfig(RealtimeVideoFormat videoFormat);
  void setNetworkQualityListener(RealtimeNetworkQualityListener? listener);
  void setPerformanceAlarmListener(RealtimePerformanceAlarmListener? listener);
  Future<void> setRemoteAudioVolume(double volume);
  Future<void> connect({
    required RealtimeSessionConnection connection,
    required void Function() ensureActive,
  });
  Future<void> disconnect();
  Future<void> beginGeneration({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
  });
  Future<void> activateRemoteAudio();
  Future<void> updateGeneration({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
  });
  Future<void> stopGeneration({required String taskID});
  Future<void> sendTracks({
    required String taskID,
    required List<RealtimePoint> points,
  });
}
