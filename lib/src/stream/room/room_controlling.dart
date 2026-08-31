import '../../service/realtime/realtime_context.dart';
import '../../service/realtime/realtime_point.dart';
import '../../service/realtime/realtime_session.dart';
import '../../service/realtime/realtime_video_format.dart';

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
  });
  Future<void> changeGenerationCondition({
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
