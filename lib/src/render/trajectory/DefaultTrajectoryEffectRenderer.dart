import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import 'TrajectoryEffectRendering.dart';

/// SDK 内置的白色核心、绿色发光轨迹效果。
final class DefaultTrajectoryEffectRenderer extends ChangeNotifier
    implements TrajectoryEffectRendering {
  static const _fadeFactor = 0.95;
  static const _idleFadeFrameLimit = 64;
  static const _activeTrailFrameLimit = 90;

  final Map<TrajectoryID, _Trajectory> _trajectories =
      <TrajectoryID, _Trajectory>{};
  late final Ticker _animationTicker = Ticker(_tick);
  int _frameIndex = 0;

  @override
  Widget get view => CustomPaint(
    painter: _TrajectoryPainter(renderer: this),
    size: Size.infinite,
  );

  @override
  void renderBegan(List<TrajectoryPoint> points) {
    for (final point in points) {
      _trajectories[point.id] = _Trajectory(
        location: point.location,
        startTime: point.timestamp,
        frameIndex: _frameIndex,
      );
    }

    _startAnimating();
    notifyListeners();
  }

  @override
  void renderMoved(List<TrajectoryPoint> points) {
    for (final point in points) {
      final trajectory = _trajectories[point.id];
      if (trajectory == null) {
        _trajectories[point.id] = _Trajectory(
          location: point.location,
          startTime: point.timestamp,
          frameIndex: _frameIndex,
        );
        continue;
      }

      trajectory.add(point.location, frameIndex: _frameIndex);
    }

    _startAnimating();
    notifyListeners();
  }

  @override
  void renderEnded(List<TrajectoryID> identifiers) {
    for (final id in identifiers) {
      final trajectory = _trajectories[id];
      if (trajectory == null) continue;

      if (trajectory.nodes.length < 2) {
        _trajectories.remove(id);
      } else {
        trajectory.finish(frameIndex: _frameIndex);
      }
    }
    notifyListeners();
  }

  @override
  void reset() {
    _trajectories.clear();
    _frameIndex = 0;
    _animationTicker.stop();
    notifyListeners();
  }

  @override
  void dispose() {
    _animationTicker.dispose();
    super.dispose();
  }

  void _startAnimating() {
    if (!_animationTicker.isActive) {
      _animationTicker.start();
    }
  }

  void _tick(Duration _) {
    _frameIndex += 1;

    _trajectories.removeWhere((_, trajectory) {
      if (!trajectory.isActive) {
        return _frameIndex - trajectory.endFrame! > _idleFadeFrameLimit;
      }

      // Keep one preceding node so the oldest visible segment remains joined.
      while (trajectory.nodes.length > 2 &&
          _frameIndex - trajectory.nodes[1].frameIndex >
              _activeTrailFrameLimit) {
        trajectory.nodes.removeAt(0);
      }
      return false;
    });

    notifyListeners();
    if (_trajectories.isEmpty) {
      _animationTicker.stop();
    }
  }
}

final class _Trajectory {
  _Trajectory({
    required Offset location,
    required this.startTime,
    required int frameIndex,
  }) : nodes = <_TrailNode>[
         _TrailNode(location: location, frameIndex: frameIndex),
       ];

  final Duration startTime;
  final List<_TrailNode> nodes;
  bool isActive = true;
  int? endFrame;

  Offset get location => nodes.last.location;

  void add(Offset location, {required int frameIndex}) {
    if ((location - this.location).distanceSquared < 0.25) return;

    isActive = true;
    endFrame = null;
    nodes.add(_TrailNode(location: location, frameIndex: frameIndex));
  }

  void finish({required int frameIndex}) {
    isActive = false;
    endFrame = frameIndex;
  }
}

final class _TrailNode {
  const _TrailNode({required this.location, required this.frameIndex});

  final Offset location;
  final int frameIndex;
}

final class _TrajectoryPainter extends CustomPainter {
  _TrajectoryPainter({required this.renderer}) : super(repaint: renderer);

  static const _coreColor = Colors.white;
  static const _glowColor = Color(0xFF00FF64);
  static const _coreWidth = 3.0;
  static const _glowWidth = 18.0;
  static const _opacityBucketCount = 6;

  final DefaultTrajectoryEffectRenderer renderer;

  @override
  void paint(Canvas canvas, Size size) {
    // Merge every visible segment into a fixed number of opacity paths. This
    // keeps the draw-call count bounded as a gesture grows; drawing and
    // blurring every individual segment causes visible jank over RTC video.
    final paths = List<Path>.generate(_opacityBucketCount, (_) => Path());
    final hasSegments = List<bool>.filled(_opacityBucketCount, false);

    for (final trajectory in renderer._trajectories.values) {
      for (var index = 1; index < trajectory.nodes.length; index += 1) {
        final start = trajectory.nodes[index - 1];
        final end = trajectory.nodes[index];
        final age = renderer._frameIndex - end.frameIndex;
        final opacity = math
            .pow(DefaultTrajectoryEffectRenderer._fadeFactor, age)
            .toDouble();
        if (opacity < 0.01) continue;

        final bucketIndex = ((opacity * _opacityBucketCount).ceil() - 1).clamp(
          0,
          _opacityBucketCount - 1,
        );
        paths[bucketIndex]
          ..moveTo(start.location.dx, start.location.dy)
          ..lineTo(end.location.dx, end.location.dy);
        hasSegments[bucketIndex] = true;
      }
    }

    for (var index = 0; index < paths.length; index += 1) {
      if (!hasSegments[index]) continue;
      _drawTrailPath(
        canvas,
        paths[index],
        opacity: (index + 1) / _opacityBucketCount,
      );
    }

    final now = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
    for (final trajectory in renderer._trajectories.values) {
      if (!trajectory.isActive) continue;

      final elapsed = math.max(
        0.0,
        (now - trajectory.startTime).inMicroseconds /
            Duration.microsecondsPerSecond,
      );
      _drawPulsingRings(canvas, trajectory.location, elapsed);
      _drawOrbitParticles(canvas, trajectory.location, elapsed);
      _drawHeadGlow(canvas, trajectory.location);
    }
  }

  void _drawTrailPath(Canvas canvas, Path path, {required double opacity}) {
    canvas.drawPath(
      path,
      Paint()
        ..color = _glowColor.withValues(alpha: 0.22 * opacity)
        ..strokeWidth = _glowWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
        ..blendMode = BlendMode.plus,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _glowColor.withValues(alpha: 0.52 * opacity)
        ..strokeWidth = 10
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
        ..blendMode = BlendMode.plus,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = _coreColor.withValues(alpha: 0.82 * opacity)
        ..strokeWidth = _coreWidth
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke
        ..blendMode = BlendMode.plus,
    );
  }

  void _drawHeadGlow(Canvas canvas, Offset point) {
    const glowRadius = 16.0;
    final bounds = Rect.fromCircle(center: point, radius: glowRadius);
    canvas.drawCircle(
      point,
      glowRadius,
      Paint()
        ..shader = const RadialGradient(
          colors: <Color>[
            Color(0xE600FF64),
            Color(0x8A00FF64),
            Color(0x0000FF64),
          ],
          stops: <double>[0, 0.4, 1],
        ).createShader(bounds),
    );
    canvas.drawCircle(point, 5, Paint()..color = _coreColor);
  }

  void _drawPulsingRings(Canvas canvas, Offset point, double elapsed) {
    for (var index = 0; index < 2; index += 1) {
      final indexValue = index.toDouble();
      final baseRadius = 14 + indexValue * 18;
      final pulseOffset = elapsed * 1.2 + indexValue * 0.5;
      final pulse = (math.sin(pulseOffset * math.pi * 2) + 1) / 2;
      final radius = baseRadius + pulse * 8;
      final alpha = 0.5 * (1 - indexValue * 0.2) * (0.5 + pulse * 0.5);

      canvas.drawCircle(
        point,
        radius,
        Paint()
          ..color = _glowColor.withValues(alpha: alpha)
          ..strokeWidth = 2
          ..style = PaintingStyle.stroke,
      );
    }
  }

  void _drawOrbitParticles(Canvas canvas, Offset point, double elapsed) {
    for (var index = 0; index < 4; index += 1) {
      final indexValue = index.toDouble();
      final direction = index.isEven ? 1.0 : -1.0;
      final baseAngle = indexValue / 4 * math.pi * 2;
      final angle = baseAngle + elapsed * 0.06 * direction;
      final center = Offset(
        point.dx + math.cos(angle) * 22,
        point.dy + math.sin(angle) * 22,
      );
      final alpha = 0.6 * (0.6 + math.sin(elapsed * 3 + indexValue) * 0.4);
      final bounds = Rect.fromCircle(center: center, radius: 6);

      canvas.drawCircle(
        center,
        6,
        Paint()
          ..shader = RadialGradient(
            colors: <Color>[
              _glowColor.withValues(alpha: alpha),
              _glowColor.withValues(alpha: 0),
            ],
          ).createShader(bounds),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TrajectoryPainter oldDelegate) => false;
}
