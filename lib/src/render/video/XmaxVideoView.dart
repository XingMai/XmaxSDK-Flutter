import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:volc_engine_rtc/volc_engine_rtc.dart';

import '../../foundation/media/video/VideoContentMode.dart';
import '../../media/interaction/InteractionFrame.dart';
import '../../service/realtime/RealtimeVideoTrack.dart';
import '../trajectory/DefaultTrajectoryEffectRenderer.dart';
import '../trajectory/TrajectoryEffectRendering.dart';
import '../trajectory/TrajectoryRegistry.dart';
import 'VideoRenderBinding.dart';
import 'VideoRenderRegistry.dart';

/// 显示 Xmax 本地或远端实时视频轨道的 Flutter 视图。
final class XmaxVideoView extends StatefulWidget {
  const XmaxVideoView({
    super.key,
    this.track,
    this.videoContentMode = VideoContentMode.fill,
    this.isInteractionEnabled = true,
    this.trajectoryRenderer,
  });

  final RealtimeVideoTrack? track;
  final VideoContentMode videoContentMode;
  final bool isInteractionEnabled;
  final TrajectoryEffectRendering? trajectoryRenderer;

  @override
  State<XmaxVideoView> createState() => _XmaxVideoViewState();
}

final class _XmaxVideoViewState extends State<XmaxVideoView>
    with SingleTickerProviderStateMixin {
  static const _samplingInterval = Duration(
    microseconds: Duration.microsecondsPerSecond ~/ 30,
  );

  late TrajectoryEffectRendering _renderer;
  late bool _ownsRenderer;
  late final Ticker _samplingTicker;
  final Map<int, _ActivePointer> _activePointers = <int, _ActivePointer>{};
  Duration _currentSamplingTime = Duration.zero;
  Duration? _lastSampleTime;
  Size? _samplingViewportSize;
  void Function(InteractionFrame frame)? _samplingListener;

  @override
  void initState() {
    super.initState();
    _ownsRenderer = widget.trajectoryRenderer == null;
    _renderer = widget.trajectoryRenderer ?? DefaultTrajectoryEffectRenderer();
    _samplingTicker = createTicker(_sampleActivePointers);
  }

  @override
  void didUpdateWidget(covariant XmaxVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    final rendererChanged =
        oldWidget.trajectoryRenderer != widget.trajectoryRenderer;
    if (rendererChanged ||
        oldWidget.track != widget.track ||
        oldWidget.isInteractionEnabled != widget.isInteractionEnabled) {
      _resetPointers();
    }

    if (rendererChanged) {
      _disposeOwnedRenderer();
      _ownsRenderer = widget.trajectoryRenderer == null;
      _renderer =
          widget.trajectoryRenderer ?? DefaultTrajectoryEffectRenderer();
    }
  }

  @override
  void dispose() {
    _resetPointers();
    _disposeOwnedRenderer();
    _samplingTicker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final track = widget.track;
    if (track == null) {
      return const ColoredBox(color: Colors.black);
    }

    final handle = VideoRenderRegistry.handleFor(track);
    final video = handle == null
        ? const ColoredBox(color: Colors.black)
        : ValueListenableBuilder<VideoRenderBinding?>(
            valueListenable: handle,
            builder: (context, binding, _) => _buildVideo(binding),
          );

    final interaction = TrajectoryRegistry.bindingFor(track);

    return ColoredBox(
      color: Colors.black,
      child: Stack(
        fit: StackFit.expand,
        children: <Widget>[
          video,
          if (widget.isInteractionEnabled && interaction != null)
            LayoutBuilder(
              builder: (context, constraints) => Listener(
                behavior: HitTestBehavior.opaque,
                onPointerDown: (event) => _pointerDown(
                  event,
                  constraints.biggest,
                  interaction.interactionListener,
                ),
                onPointerMove: (event) => _pointerMove(
                  event,
                  constraints.biggest,
                  interaction.interactionListener,
                ),
                onPointerUp: _pointerUp,
                onPointerCancel: _pointerUp,
                child: IgnorePointer(child: _renderer.view),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildVideo(VideoRenderBinding? binding) {
    if (binding == null) {
      return const ColoredBox(color: Colors.black);
    }

    final RTCViewContext viewContext;

    if (binding is LocalVideoRenderBinding) {
      viewContext = RTCViewContext.localContext(userId: 'local');
    } else if (binding is RemoteVideoRenderBinding) {
      viewContext = RTCViewContext.remoteContext(
        roomId: binding.stream.roomID,
        userId: binding.stream.userID,
        streamId: binding.stream.streamID,
      );
    } else {
      return const ColoredBox(color: Colors.black);
    }

    // The VolcEngine plugin defaults to SurfaceView even though its Flutter
    // documentation recommends TextureView on Android. A SurfaceView nested in
    // Flutter's virtual display can exhaust the ImageReader buffer queue while
    // the remote decoder starts, which blocks the Android main thread.
    if (defaultTargetPlatform == TargetPlatform.android) {
      viewContext.viewType = 'texture';
    }

    return RTCSurfaceView(
      key: ValueKey<String>(
        '${viewContext.canvasType}:${viewContext.roomId}:'
        '${viewContext.userId}:${viewContext.streamId}',
      ),
      context: viewContext,
      renderMode: widget.videoContentMode == VideoContentMode.fit
          ? VideoRenderMode.fit
          : VideoRenderMode.hidden,
      // VolcEngine's Android bridge reflects this value into a signed Java
      // int. An ARGB value such as 0xFF000000 is serialized as 4278190080 and
      // fails that conversion; RGB black matches the plugin default.
      backgroundColor: 0x000000,
    );
  }

  void _pointerDown(
    PointerDownEvent event,
    Size size,
    void Function(InteractionFrame frame) listener,
  ) {
    final pointer = _ActivePointer(
      id: createTrajectoryID(event.pointer),
      location: event.localPosition,
    );

    _activePointers[event.pointer] = pointer;
    _updateSamplingContext(size, listener);
    _renderer.renderBegan(<TrajectoryPoint>[_point(pointer, size)]);

    // Match iOS: submit the first touch immediately, then let the display
    // ticker continuously sample every active pointer at 30 Hz.
    _submit(size, listener);
    if (!_samplingTicker.isActive) {
      _currentSamplingTime = Duration.zero;
      _lastSampleTime = Duration.zero;
      _samplingTicker.start();
    } else {
      _lastSampleTime = _currentSamplingTime;
    }
  }

  void _pointerMove(
    PointerMoveEvent event,
    Size size,
    void Function(InteractionFrame frame) listener,
  ) {
    final pointer = _activePointers[event.pointer];
    if (pointer == null) {
      return;
    }

    pointer.location = event.localPosition;
    _updateSamplingContext(size, listener);
    _renderer.renderMoved(<TrajectoryPoint>[_point(pointer, size)]);
  }

  void _pointerUp(PointerEvent event) {
    final pointer = _activePointers.remove(event.pointer);
    if (pointer != null) {
      _renderer.renderEnded(<TrajectoryID>[pointer.id]);
    }

    if (_activePointers.isEmpty) {
      _stopSampling();
    }
  }

  void _sampleActivePointers(Duration elapsed) {
    _currentSamplingTime = elapsed;

    if (_activePointers.isEmpty) {
      _stopSampling();
      return;
    }

    final lastSampleTime = _lastSampleTime;
    if (lastSampleTime != null &&
        elapsed - lastSampleTime < _samplingInterval) {
      return;
    }

    final size = _samplingViewportSize;
    final listener = _samplingListener;
    if (size == null || listener == null) {
      return;
    }

    _submit(size, listener);
    _lastSampleTime = elapsed;
  }

  void _updateSamplingContext(
    Size size,
    void Function(InteractionFrame frame) listener,
  ) {
    _samplingViewportSize = size;
    _samplingListener = listener;
  }

  void _stopSampling() {
    if (_samplingTicker.isActive) {
      _samplingTicker.stop();
    }
    _currentSamplingTime = Duration.zero;
    _lastSampleTime = null;
    _samplingViewportSize = null;
    _samplingListener = null;
  }

  TrajectoryPoint _point(_ActivePointer pointer, Size size) => TrajectoryPoint(
    id: pointer.id,
    location: pointer.location,
    normalizedLocation: Offset(
      size.width == 0 ? 0 : pointer.location.dx / size.width,
      size.height == 0 ? 0 : pointer.location.dy / size.height,
    ),
    timestamp: Duration(microseconds: DateTime.now().microsecondsSinceEpoch),
  );

  void _submit(Size size, void Function(InteractionFrame frame) listener) {
    listener(
      InteractionFrame(
        points: _activePointers.values
            .map((pointer) => pointer.location)
            .toList(growable: false),
        viewportSize: size,
        contentMode: widget.videoContentMode,
      ),
    );
  }

  void _resetPointers() {
    _activePointers.clear();
    _stopSampling();
    _renderer.reset();
  }

  void _disposeOwnedRenderer() {
    if (_ownsRenderer && _renderer is DefaultTrajectoryEffectRenderer) {
      (_renderer as DefaultTrajectoryEffectRenderer).dispose();
    }
  }
}

final class _ActivePointer {
  _ActivePointer({required this.id, required this.location});

  final TrajectoryID id;
  Offset location;
}
