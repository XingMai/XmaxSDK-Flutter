import '../service/realtime/realtime_context.dart';
import '../service/realtime/realtime_network_quality.dart';
import '../service/realtime/realtime_performance_alarm.dart';
import '../service/realtime/realtime_point.dart';
import '../service/realtime/realtime_session.dart';
import '../service/realtime/realtime_video_format.dart';

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
