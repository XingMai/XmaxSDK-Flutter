import 'package:flutter/material.dart';
import 'package:volc_engine_rtc/volc_engine_rtc.dart';

import '../../foundation/media/video/video_content_mode.dart';
import '../../media/interaction/interaction_frame.dart';
import '../../service/realtime/realtime_video_track.dart';
import '../trajectory/default_trajectory_effect_renderer.dart';
import '../trajectory/trajectory_effect_rendering.dart';
import '../trajectory/trajectory_registry.dart';
import 'video_render_binding.dart';
import 'video_render_registry.dart';

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

final class _XmaxVideoViewState extends State<XmaxVideoView> {
  late TrajectoryEffectRendering _renderer;
  final Map<int, _ActivePointer> _activePointers = <int, _ActivePointer>{};

  @override
  void initState() {
    super.initState();
    _renderer = widget.trajectoryRenderer ?? DefaultTrajectoryEffectRenderer();
  }

  @override
  void didUpdateWidget(covariant XmaxVideoView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.trajectoryRenderer != widget.trajectoryRenderer) {
      _renderer.reset();
      _renderer =
          widget.trajectoryRenderer ?? DefaultTrajectoryEffectRenderer();
    }
    if (oldWidget.track != widget.track ||
        oldWidget.isInteractionEnabled != widget.isInteractionEnabled) {
      _resetPointers();
    }
  }

  @override
  void dispose() {
    _resetPointers();
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
    return RTCSurfaceView(
      key: ValueKey<String>(
        '${viewContext.canvasType}:${viewContext.roomId}:'
        '${viewContext.userId}:${viewContext.streamId}',
      ),
      context: viewContext,
      renderMode: widget.videoContentMode == VideoContentMode.fit
          ? VideoRenderMode.fit
          : VideoRenderMode.hidden,
      backgroundColor: 0xFF000000,
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
    _renderer.renderBegan(<TrajectoryPoint>[_point(pointer, size)]);
    _submit(size, listener);
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
    _renderer.renderMoved(<TrajectoryPoint>[_point(pointer, size)]);
    _submit(size, listener);
  }

  void _pointerUp(PointerEvent event) {
    final pointer = _activePointers.remove(event.pointer);
    if (pointer != null) {
      _renderer.renderEnded(<TrajectoryID>[pointer.id]);
    }
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
    _renderer.reset();
  }
}

final class _ActivePointer {
  _ActivePointer({required this.id, required this.location});

  final TrajectoryID id;
  Offset location;
}
