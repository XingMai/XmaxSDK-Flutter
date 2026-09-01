import 'dart:typed_data';

import '../../service/realtime/RealtimeNetworkQuality.dart';
import '../../service/realtime/RealtimePerformanceAlarm.dart';
import 'RtcModels.dart';

final class RtcEventListener {
  const RtcEventListener({
    this.onRemoteVideoPublished,
    this.onSEIMessageReceived,
    this.onError,
    this.onNetworkQuality,
    this.onPerformanceAlarm,
  });

  final void Function(RemoteStream stream, bool published)?
  onRemoteVideoPublished;
  final void Function(RemoteStream stream, Uint8List message)?
  onSEIMessageReceived;
  final void Function(Object error)? onError;
  final void Function(RealtimeNetworkQuality quality)? onNetworkQuality;
  final void Function(RealtimePerformanceAlarm alarm)? onPerformanceAlarm;
}
