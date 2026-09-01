import '../../service/realtime/RealtimeVideoTrack.dart';
import 'TrajectoryBinding.dart';

abstract final class TrajectoryRegistry {
  static final Map<RealtimeVideoTrack, TrajectoryBinding> _bindings =
      <RealtimeVideoTrack, TrajectoryBinding>{};

  static void register(RealtimeVideoTrack track, TrajectoryBinding binding) {
    _bindings[track] = binding;
  }

  static void unregister(RealtimeVideoTrack track) {
    _bindings.remove(track);
  }

  static TrajectoryBinding? bindingFor(RealtimeVideoTrack track) =>
      _bindings[track];
}
