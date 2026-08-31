import 'dart:typed_data';

import '../../service/realtime/realtime_network_quality.dart';
import '../../service/realtime/realtime_performance_alarm.dart';
import 'rtc_models.dart';

final class RtcEventListener {
  const RtcEventListener({
    this.onRemoteVideoPublished,
    this.onSEIMessageReceived,
    this.onFirstRemoteVideoFrameDecoded,
    this.onError,
    this.onNetworkQuality,
    this.onPerformanceAlarm,
  });

  final void Function(RemoteStream stream, bool published)?
  onRemoteVideoPublished;
  final void Function(RemoteStream stream, Uint8List message)?
  onSEIMessageReceived;
  final void Function(RemoteStream stream)? onFirstRemoteVideoFrameDecoded;
  final void Function(Object error)? onError;
  final void Function(RealtimeNetworkQuality quality)? onNetworkQuality;
  final void Function(RealtimePerformanceAlarm alarm)? onPerformanceAlarm;
}
