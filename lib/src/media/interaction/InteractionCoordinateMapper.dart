import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../foundation/media/video/VideoContentMode.dart';
import '../../service/realtime/RealtimePoint.dart';

abstract final class InteractionCoordinateMapper {
  static Rect? displayedFrame({
    required Size viewportSize,
    required Size videoSize,
    required VideoContentMode contentMode,
  }) {
    if (viewportSize.width <= 0 ||
        viewportSize.height <= 0 ||
        videoSize.width <= 0 ||
        videoSize.height <= 0) {
      return null;
    }
    final widthScale = viewportSize.width / videoSize.width;
    final heightScale = viewportSize.height / videoSize.height;
    final scale = contentMode == VideoContentMode.fill
        ? math.max(widthScale, heightScale)
        : math.min(widthScale, heightScale);
    final displayedSize = Size(
      videoSize.width * scale,
      videoSize.height * scale,
    );
    return Rect.fromLTWH(
      (viewportSize.width - displayedSize.width) / 2,
      (viewportSize.height - displayedSize.height) / 2,
      displayedSize.width,
      displayedSize.height,
    );
  }

  static RealtimePoint? map({
    required Offset point,
    required Size viewportSize,
    required Size videoSize,
    required VideoContentMode contentMode,
  }) {
    final frame = displayedFrame(
      viewportSize: viewportSize,
      videoSize: videoSize,
      contentMode: contentMode,
    );
    if (!point.dx.isFinite || !point.dy.isFinite || frame == null) {
      return null;
    }
    if (contentMode == VideoContentMode.fit && !frame.contains(point)) {
      return null;
    }
    final scale = frame.width / videoSize.width;
    final x = ((point.dx - frame.left) / scale).round().clamp(
      0,
      videoSize.width.toInt() - 1,
    );
    final y = ((point.dy - frame.top) / scale).round().clamp(
      0,
      videoSize.height.toInt() - 1,
    );
    return RealtimePoint(x: x.toDouble(), y: y.toDouble());
  }
}
