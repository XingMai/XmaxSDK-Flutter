import 'dart:async';

import '../foundation/errors/XmaxError.dart';
import '../foundation/rtc/RtcModels.dart';
import '../media/interaction/InteractionFrame.dart';
import '../service/realtime/RealtimeVideoTrack.dart';
import 'RenderControlling.dart';
import 'trajectory/TrajectoryBinding.dart';
import 'trajectory/TrajectoryRegistry.dart';
import 'video/VideoRenderBinding.dart';
import 'video/VideoRenderRegistry.dart';

final class RenderController implements RenderControlling {
  RenderController({
    this.remoteFrameReadyTimeout = const Duration(seconds: 10),
  });

  final Duration remoteFrameReadyTimeout;
  RealtimeVideoTrack? _remoteTrack;
  RemoteStream? _remoteStream;
  bool _remoteFrameReady = false;
  final Set<Completer<void>> _frameWaiters = {};

  @override
  Future<void> prepareForRemoteRemoval() async {
    final track = _remoteTrack;
    if (track != null) {
      await VideoRenderRegistry.handleFor(track)?.prepareForRemoval();
    }
  }

  @override
  void registerRemoteTrack(
    RealtimeVideoTrack track, {
    required void Function(InteractionFrame frame) interactionListener,
  }) {
    _resetFrameReadiness();
    _remoteTrack = track;
    VideoRenderRegistry.register(track, null);
    TrajectoryRegistry.register(
      track,
      TrajectoryBinding(interactionListener: interactionListener),
    );
  }

  @override
  void setRemoteStream(RemoteStream? stream) {
    _resetFrameReadiness();
    _remoteStream = stream;
    final track = _remoteTrack;
    if (track != null) {
      VideoRenderRegistry.register(
        track,
        stream == null ? null : RemoteVideoRenderBinding(stream),
      );
    }
  }

  /// Decoding readiness is independent of whether a consumer mounted a view.
  void markRemoteFrameReady(RemoteStream stream) {
    final active = _remoteStream;
    if (_remoteTrack == null ||
        active == null ||
        active.roomID != stream.roomID ||
        active.userID != stream.userID ||
        active.streamID != stream.streamID) {
      return;
    }
    _remoteFrameReady = true;
    for (final waiter in _frameWaiters) {
      if (!waiter.isCompleted) waiter.complete();
    }
    _frameWaiters.clear();
  }

  @override
  Future<void> waitUntilRemoteFrameReady() async {
    if (_remoteTrack == null || _remoteStream == null) {
      throw const XmaxError(
        code: XmaxErrorCode.rtcError,
        message: 'Remote video stream is unavailable',
      );
    }
    if (_remoteFrameReady) return;
    final waiter = Completer<void>();
    _frameWaiters.add(waiter);
    try {
      await waiter.future.timeout(
        remoteFrameReadyTimeout,
        onTimeout: () {
          throw const XmaxError(
            code: XmaxErrorCode.timeout,
            message: 'Remote video first frame timed out',
          );
        },
      );
    } finally {
      _frameWaiters.remove(waiter);
    }
  }

  void _resetFrameReadiness() {
    _remoteStream = null;
    _remoteFrameReady = false;
    for (final waiter in _frameWaiters) {
      if (!waiter.isCompleted) {
        waiter.completeError(
          const XmaxError(
            code: XmaxErrorCode.cancelled,
            message: 'Remote frame wait cancelled',
          ),
        );
      }
    }
    _frameWaiters.clear();
  }

  void markRemoteFrameRendered(RemoteStream stream) {
    final track = _remoteTrack;
    if (track == null) return;

    final handle = VideoRenderRegistry.handleFor(track);
    final binding = handle?.value;
    if (binding is! RemoteVideoRenderBinding ||
        binding.firstFrameRendered ||
        binding.stream.roomID != stream.roomID ||
        binding.stream.userID != stream.userID ||
        binding.stream.streamID != stream.streamID) {
      return;
    }

    VideoRenderRegistry.register(
      track,
      RemoteVideoRenderBinding(stream, firstFrameRendered: true),
    );
  }

  @override
  void resetRemoteTrack(RealtimeVideoTrack? track) {
    _resetFrameReadiness();
    final target = track ?? _remoteTrack;
    if (target != null) {
      VideoRenderRegistry.unregister(target);
      TrajectoryRegistry.unregister(target);
    }

    _remoteTrack = null;
  }
}
