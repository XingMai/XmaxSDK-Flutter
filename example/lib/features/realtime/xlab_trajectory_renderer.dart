import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:xmax_sdk/xmax_sdk.dart';

/// XLab 自定义轨迹效果，以粉、蓝双色区分多指轨迹。
final class XLabTrajectoryRenderer extends ChangeNotifier
    implements TrajectoryEffectRendering {
  static const _fadeFactor = 0.93;
  static const _idleFadeFrameLimit = 48;
  static const _activeTrailFrameLimit = 66;
  static const _palette = <_TrajectoryColors>[
    _TrajectoryColors(core: Color(0xFFFFE6FA), glow: Color(0xFFFF2EB8)),
    _TrajectoryColors(core: Color(0xFFE6FAFF), glow: Color(0xFF24BDFF)),
  ];

  final Map<TrajectoryID, _Trajectory> _trajectories =
      <TrajectoryID, _Trajectory>{};
  late final Ticker _animationTicker = Ticker(_tick);
  int _frameIndex = 0;
  int _nextPaletteIndex = 0;

  @override
  Widget get view => CustomPaint(
    painter: _XLabTrajectoryPainter(renderer: this),
    size: Size.infinite,
  );

  @override
  void renderBegan(List<TrajectoryPoint> points) {
    for (final point in points) {
      final paletteIndex = _nextPaletteIndex % _palette.length;
      _nextPaletteIndex += 1;
      _trajectories[point.id] = _Trajectory(
        location: point.location,
        startTime: point.timestamp,
        frameIndex: _frameIndex,
        paletteIndex: paletteIndex,
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
        final paletteIndex = _nextPaletteIndex % _palette.length;
        _nextPaletteIndex += 1;
        _trajectories[point.id] = _Trajectory(
          location: point.location,
          startTime: point.timestamp,
          frameIndex: _frameIndex,
          paletteIndex: paletteIndex,
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
    _nextPaletteIndex = 0;
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

  void _tick(Duration elapsed) {
    // Match the 60 fps fade cadence used by the iOS renderer even when the
    // Flutter view is hosted on a 90/120 Hz display.
    _frameIndex = elapsed.inMicroseconds * 60 ~/ Duration.microsecondsPerSecond;
    _trajectories.removeWhere((_, trajectory) {
      if (!trajectory.isActive) {
        return _frameIndex - trajectory.endFrame! > _idleFadeFrameLimit;
      }

      // Retain one predecessor so the oldest visible segment remains joined.
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
      _frameIndex = 0;
    }
  }
}

final class _Trajectory {
  _Trajectory({
    required Offset location,
    required this.startTime,
    required int frameIndex,
    required this.paletteIndex,
  }) : nodes = <_TrailNode>[
         _TrailNode(location: location, frameIndex: frameIndex),
       ];

  final Duration startTime;
  final int paletteIndex;
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

final class _TrajectoryColors {
  const _TrajectoryColors({required this.core, required this.glow});

  final Color core;
  final Color glow;
}

final class _XLabTrajectoryPainter extends CustomPainter {
  _XLabTrajectoryPainter({required this.renderer}) : super(repaint: renderer);

  static const _cohortFrameSpan = 6;
  static const _cohortCount = 12;
  static const _coreWidth = 6.0;
  static const _glowWidth = 18.0;

  final XLabTrajectoryRenderer renderer;
  final List<List<Path>> _paths = List<List<Path>>.generate(
    XLabTrajectoryRenderer._palette.length,
    (_) => List<Path>.generate(_cohortCount, (_) => Path()),
  );
  final List<List<int?>> _cohortIDs = List<List<int?>>.generate(
    XLabTrajectoryRenderer._palette.length,
    (_) => List<int?>.filled(_cohortCount, null),
  );
  final Paint _outerGlowPaint = Paint()
    ..strokeWidth = _glowWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 12)
    ..blendMode = BlendMode.plus;
  final Paint _innerGlowPaint = Paint()
    ..strokeWidth = 10
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke
    ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6)
    ..blendMode = BlendMode.plus;
  final Paint _trailCorePaint = Paint()
    ..strokeWidth = _coreWidth
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round
    ..style = PaintingStyle.stroke
    ..blendMode = BlendMode.plus;
  final Paint _effectPaint = Paint()..blendMode = BlendMode.plus;
  final Paint _ringPaint = Paint()
    ..strokeWidth = 2
    ..style = PaintingStyle.stroke
    ..blendMode = BlendMode.plus;
  final Paint _headCorePaint = Paint()..blendMode = BlendMode.plus;

  @override
  void paint(Canvas canvas, Size size) {
    for (
      var paletteIndex = 0;
      paletteIndex < XLabTrajectoryRenderer._palette.length;
      paletteIndex += 1
    ) {
      for (var cohortSlot = 0; cohortSlot < _cohortCount; cohortSlot += 1) {
        _paths[paletteIndex][cohortSlot].reset();
        _cohortIDs[paletteIndex][cohortSlot] = null;
      }
    }

    // Stable time cohorts preserve additive overlap while fading. Moving a
    // segment between opacity buckets makes the trail look like it is flowing.
    for (final trajectory in renderer._trajectories.values) {
      for (var index = 1; index < trajectory.nodes.length; index += 1) {
        final start = trajectory.nodes[index - 1];
        final end = trajectory.nodes[index];
        final age = renderer._frameIndex - end.frameIndex;
        final opacity = math
            .pow(XLabTrajectoryRenderer._fadeFactor, age)
            .toDouble();
        if (opacity < 0.01) continue;

        final cohortID = end.frameIndex ~/ _cohortFrameSpan;
        final cohortSlot = cohortID % _cohortCount;
        if (_cohortIDs[trajectory.paletteIndex][cohortSlot] != cohortID) {
          _paths[trajectory.paletteIndex][cohortSlot].reset();
          _cohortIDs[trajectory.paletteIndex][cohortSlot] = cohortID;
        }
        _paths[trajectory.paletteIndex][cohortSlot]
          ..moveTo(start.location.dx, start.location.dy)
          ..lineTo(end.location.dx, end.location.dy);
      }
    }

    for (
      var paletteIndex = 0;
      paletteIndex < XLabTrajectoryRenderer._palette.length;
      paletteIndex += 1
    ) {
      final colors = XLabTrajectoryRenderer._palette[paletteIndex];
      for (var cohortSlot = 0; cohortSlot < _cohortCount; cohortSlot += 1) {
        final cohortID = _cohortIDs[paletteIndex][cohortSlot];
        if (cohortID == null) continue;

        final cohortMiddleFrame =
            cohortID * _cohortFrameSpan + (_cohortFrameSpan - 1) / 2;
        final age = math.max(0.0, renderer._frameIndex - cohortMiddleFrame);
        final opacity = math
            .pow(XLabTrajectoryRenderer._fadeFactor, age)
            .toDouble();
        _drawTrailPath(
          canvas,
          _paths[paletteIndex][cohortSlot],
          colors: colors,
          opacity: opacity,
        );
      }
    }

    final now = Duration(microseconds: DateTime.now().microsecondsSinceEpoch);
    for (final trajectory in renderer._trajectories.values) {
      if (!trajectory.isActive) continue;

      final elapsed = math.max(
        0.0,
        (now - trajectory.startTime).inMicroseconds /
            Duration.microsecondsPerSecond,
      );
      final colors = XLabTrajectoryRenderer._palette[trajectory.paletteIndex];
      _drawPulsingRings(canvas, trajectory.location, elapsed, colors.glow);
      _drawOrbitParticles(canvas, trajectory.location, elapsed, colors.glow);
      _drawHeadGlow(canvas, trajectory.location, colors);
    }
  }

  void _drawTrailPath(
    Canvas canvas,
    Path path, {
    required _TrajectoryColors colors,
    required double opacity,
  }) {
    _outerGlowPaint.color = colors.glow.withValues(alpha: 0.18 * opacity);
    canvas.drawPath(path, _outerGlowPaint);

    _innerGlowPaint.color = colors.glow.withValues(alpha: 0.44 * opacity);
    canvas.drawPath(path, _innerGlowPaint);

    _trailCorePaint.color = colors.core.withValues(alpha: 0.72 * opacity);
    canvas.drawPath(path, _trailCorePaint);
  }

  void _drawHeadGlow(Canvas canvas, Offset point, _TrajectoryColors colors) {
    const radius = 16.0;
    final bounds = Rect.fromCircle(center: point, radius: radius);
    _effectPaint.shader = RadialGradient(
      colors: <Color>[
        colors.glow.withValues(alpha: 0.76),
        colors.glow.withValues(alpha: 0.456),
        colors.glow.withValues(alpha: 0),
      ],
      stops: const <double>[0, 0.4, 1],
    ).createShader(bounds);
    canvas.drawCircle(point, radius, _effectPaint);

    _headCorePaint.color = colors.core.withValues(alpha: 0.88);
    canvas.drawCircle(point, 5, _headCorePaint);
  }

  void _drawPulsingRings(
    Canvas canvas,
    Offset point,
    double elapsed,
    Color glowColor,
  ) {
    for (var index = 0; index < 2; index += 1) {
      final indexValue = index.toDouble();
      final pulse =
          (math.sin((elapsed * 1.2 + indexValue * 0.5) * math.pi * 2) + 1) / 2;
      final radius = 14 + indexValue * 18 + pulse * 8;
      final alpha = 0.42 * (1 - indexValue * 0.2) * (0.5 + pulse * 0.5);
      _ringPaint.color = glowColor.withValues(alpha: alpha);
      canvas.drawCircle(point, radius, _ringPaint);
    }
  }

  void _drawOrbitParticles(
    Canvas canvas,
    Offset point,
    double elapsed,
    Color glowColor,
  ) {
    for (var index = 0; index < 4; index += 1) {
      final indexValue = index.toDouble();
      final direction = index.isEven ? 1.0 : -1.0;
      final baseAngle = indexValue / 4 * math.pi * 2;
      final angle = baseAngle + elapsed * 0.06 * direction;
      final center = Offset(
        point.dx + math.cos(angle) * 22,
        point.dy + math.sin(angle) * 22,
      );
      final alpha = 0.5 * (0.6 + math.sin(elapsed * 3 + indexValue) * 0.4);
      final bounds = Rect.fromCircle(center: center, radius: 6);
      _effectPaint.shader = RadialGradient(
        colors: <Color>[
          glowColor.withValues(alpha: alpha),
          glowColor.withValues(alpha: alpha * 0.6),
          glowColor.withValues(alpha: 0),
        ],
        stops: const <double>[0, 0.4, 1],
      ).createShader(bounds);
      canvas.drawCircle(center, 6, _effectPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _XLabTrajectoryPainter oldDelegate) => false;
}
