import '../service/realtime/RealtimeContext.dart';
import '../service/realtime/RealtimeNetworkQuality.dart';
import '../service/realtime/RealtimePerformanceAlarm.dart';
import '../service/realtime/RealtimePoint.dart';
import '../service/realtime/RealtimeSession.dart';
import '../service/realtime/RealtimeVideoFormat.dart';

/// 可取消的生成启动确认。
///
/// 启动信令发送成功后，[value] 会继续等待远端 SEI 确认；新生成请求可以
/// 调用 [cancel] 立即结束这段等待，行为与 iOS 的 confirmation task 一致。
final class GenerationStartConfirmation {
  GenerationStartConfirmation({
    required this.value,
    required void Function() onCancel,
  }) : _onCancel = onCancel;

  final Future<void> value;
  final void Function() _onCancel;

  void cancel() => _onCancel();
}

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
  Future<GenerationStartConfirmation> beginGeneration({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
  });
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
