import '../foundation/rtc/RtcModels.dart';
import '../media/interaction/InteractionFrame.dart';
import '../service/realtime/RealtimeVideoTrack.dart';

abstract interface class RenderControlling {
  void setRemoteStream(RemoteStream? stream);
  void registerRemoteTrack(
    RealtimeVideoTrack track, {
    required void Function(InteractionFrame frame) interactionListener,
  });
  void resetRemoteTrack(RealtimeVideoTrack? track);
}
