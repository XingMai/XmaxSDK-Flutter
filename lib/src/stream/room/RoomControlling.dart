import 'dart:ui';

import '../../service/realtime/RealtimeContext.dart';
import '../../service/realtime/RealtimePoint.dart';
import '../../service/realtime/RealtimeSession.dart';
import '../../service/realtime/RealtimeVideoFormat.dart';

abstract interface class RoomControlling {
  Future<void> join({
    required RealtimeSessionConnection connection,
    required void Function() ensureActive,
  });
  Future<void> leave();
  Future<void> startGeneration({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
    Size? targetSize,
  });
  Future<void> changeGenerationCondition({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
    Size? targetSize,
  });
  Future<void> changeTargetSize({
    required String taskID,
    required Size targetSize,
    required void Function() ensureActive,
  });
  Future<void> stopGeneration({required String taskID});
  Future<void> sendTracks({
    required String taskID,
    required List<RealtimePoint> points,
  });
}
