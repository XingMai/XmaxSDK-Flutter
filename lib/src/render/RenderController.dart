import '../foundation/rtc/RtcModels.dart';
import '../media/interaction/InteractionFrame.dart';
import '../service/realtime/RealtimeVideoTrack.dart';
import 'RenderControlling.dart';
import 'trajectory/TrajectoryBinding.dart';
import 'trajectory/TrajectoryRegistry.dart';
import 'video/VideoRenderBinding.dart';
import 'video/VideoRenderRegistry.dart';

final class RenderController implements RenderControlling {
  RealtimeVideoTrack? _remoteTrack;

  @override
  void registerRemoteTrack(
    RealtimeVideoTrack track, {
    required void Function(InteractionFrame frame) interactionListener,
  }) {
    _remoteTrack = track;
    VideoRenderRegistry.register(track, null);
    TrajectoryRegistry.register(
      track,
      TrajectoryBinding(interactionListener: interactionListener),
    );
  }

  @override
  void setRemoteStream(RemoteStream? stream) {
    final track = _remoteTrack;
    if (track != null) {
      VideoRenderRegistry.register(
        track,
        stream == null ? null : RemoteVideoRenderBinding(stream),
      );
    }
  }

  @override
  void resetRemoteTrack(RealtimeVideoTrack? track) {
    final target = track ?? _remoteTrack;
    if (target != null) {
      VideoRenderRegistry.unregister(target);
      TrajectoryRegistry.unregister(target);
    }

    _remoteTrack = null;
  }
}
