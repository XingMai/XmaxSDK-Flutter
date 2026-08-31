import 'package:flutter/foundation.dart';

import '../../service/realtime/realtime_video_track.dart';
import 'video_render_binding.dart';

final class VideoRenderHandle extends ValueNotifier<VideoRenderBinding?> {
  VideoRenderHandle(super.value);
}

abstract final class VideoRenderRegistry {
  static final Map<RealtimeVideoTrack, VideoRenderHandle> _bindings =
      <RealtimeVideoTrack, VideoRenderHandle>{};

  static void register(RealtimeVideoTrack track, VideoRenderBinding? binding) {
    final current = _bindings[track];
    if (current == null) {
      _bindings[track] = VideoRenderHandle(binding);
    } else {
      current.value = binding;
    }
  }

  static void unregister(RealtimeVideoTrack track) {
    _bindings.remove(track)?.value = null;
  }

  static VideoRenderHandle? handleFor(RealtimeVideoTrack track) =>
      _bindings[track];
}
