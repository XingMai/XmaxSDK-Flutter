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
  Completer<void>? _remoteFrameCompleter;

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
    _remoteStream = stream;
    _remoteFrameReady = false;
    _cancelWaiter();
    final track = _remoteTrack;
    if (track != null) {
      VideoRenderRegistry.register(
        track,
        stream == null ? null : RemoteVideoRenderBinding(stream),
      );
    }
  }

  @override
  void notifyRemoteFrameReady(RemoteStream stream) {
    if (_remoteStream?.key != stream.key) {
      return;
    }
    _remoteFrameReady = true;
    final completer = _remoteFrameCompleter;
    _remoteFrameCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.complete();
    }
  }

  @override
  Future<void> waitUntilRemoteFrameReady() async {
    if (_remoteStream == null) {
      throw const XmaxError(
        code: XmaxErrorCode.rtcError,
        message: 'Remote video stream is unavailable',
      );
    }
    if (_remoteFrameReady) {
      return;
    }
    final completer = Completer<void>();
    _remoteFrameCompleter = completer;
    await completer.future.timeout(
      remoteFrameReadyTimeout,
      onTimeout: () => throw const XmaxError(
        code: XmaxErrorCode.timeout,
        message: 'Remote video first frame timed out',
      ),
    );
  }

  @override
  void resetRemoteTrack(RealtimeVideoTrack? track) {
    _cancelWaiter();
    _remoteFrameReady = false;
    _remoteStream = null;
    final target = track ?? _remoteTrack;
    if (target != null) {
      VideoRenderRegistry.unregister(target);
      TrajectoryRegistry.unregister(target);
    }
    _remoteTrack = null;
  }

  void _cancelWaiter() {
    final completer = _remoteFrameCompleter;
    _remoteFrameCompleter = null;
    if (completer != null && !completer.isCompleted) {
      completer.completeError(
        const XmaxError(
          code: XmaxErrorCode.cancelled,
          message: 'Remote video first frame wait cancelled',
        ),
      );
    }
  }
}
