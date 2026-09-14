import 'package:flutter/foundation.dart';

import '../../service/realtime/RealtimeVideoTrack.dart';
import 'VideoRenderBinding.dart';

final class VideoRenderHandle extends ValueNotifier<VideoRenderBinding?> {
  VideoRenderHandle(super.value);

  final Set<Future<void> Function()> _removalListeners = {};

  void addRemovalListener(Future<void> Function() listener) =>
      _removalListeners.add(listener);

  void removeRemovalListener(Future<void> Function() listener) =>
      _removalListeners.remove(listener);

  /// Mounted composite views can conceal the native surface before teardown.
  /// Headless consumers have no listeners and never wait for a Flutter frame.
  Future<void> prepareForRemoval() async {
    await Future.wait(_removalListeners.toList().map((listener) => listener()));
  }
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
