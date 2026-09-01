import 'package:flutter/material.dart';

import 'TrajectoryEffectRendering.dart';

final class DefaultTrajectoryEffectRenderer extends ChangeNotifier
    implements TrajectoryEffectRendering {
  final Map<TrajectoryID, Offset> _points = <TrajectoryID, Offset>{};

  @override
  Widget get view => CustomPaint(
    painter: _TrajectoryPainter(renderer: this),
    size: Size.infinite,
  );

  @override
  void renderBegan(List<TrajectoryPoint> points) => _update(points);

  @override
  void renderMoved(List<TrajectoryPoint> points) => _update(points);

  @override
  void renderEnded(List<TrajectoryID> identifiers) {
    for (final id in identifiers) {
      _points.remove(id);
    }
    notifyListeners();
  }

  @override
  void reset() {
    _points.clear();
    notifyListeners();
  }

  void _update(List<TrajectoryPoint> points) {
    for (final point in points) {
      _points[point.id] = point.location;
    }
    notifyListeners();
  }
}

final class _TrajectoryPainter extends CustomPainter {
  _TrajectoryPainter({required this.renderer}) : super(repaint: renderer);

  final DefaultTrajectoryEffectRenderer renderer;

  @override
  void paint(Canvas canvas, Size size) {
    final glow = Paint()
      ..color = const Color(0x663E8BFF)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 14);
    final core = Paint()..color = const Color(0xFF72A8FF);
    for (final point in renderer._points.values) {
      canvas.drawCircle(point, 19, glow);
      canvas.drawCircle(point, 6, core);
    }
  }

  @override
  bool shouldRepaint(covariant _TrajectoryPainter oldDelegate) => false;
}
