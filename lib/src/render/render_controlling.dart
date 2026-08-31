import '../foundation/rtc/rtc_models.dart';
import '../media/interaction/interaction_frame.dart';
import '../service/realtime/realtime_video_track.dart';

abstract interface class RenderControlling {
  void setRemoteStream(RemoteStream? stream);
  void registerRemoteTrack(
    RealtimeVideoTrack track, {
    required void Function(InteractionFrame frame) interactionListener,
  });
  void notifyRemoteFrameReady(RemoteStream stream);
  Future<void> waitUntilRemoteFrameReady();
  void resetRemoteTrack(RealtimeVideoTrack? track);
}
