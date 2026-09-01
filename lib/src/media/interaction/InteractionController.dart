import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../service/realtime/RealtimePoint.dart';
import '../../service/realtime/RealtimeVideoFormat.dart';
import 'InteractionControlling.dart';
import 'InteractionCoordinateMapper.dart';
import 'InteractionFrame.dart';

typedef InteractionListener =
    Future<void> Function(String taskID, List<RealtimePoint> points);

final class InteractionController implements InteractionControlling {
  InteractionController({required InteractionListener listener})
    : _listener = listener;

  final InteractionListener _listener;
  String? _taskID;
  RealtimeVideoFormat? _videoFormat;
  List<RealtimePoint>? _pendingPoints;
  bool _draining = false;

  @override
  void startInteraction({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
  }) {
    _pendingPoints = null;
    _taskID = taskID;
    _videoFormat = videoFormat;
  }

  @override
  void stopInteraction() {
    _taskID = null;
    _videoFormat = null;
    _pendingPoints = null;
  }

  @override
  void submitInteraction(InteractionFrame frame) {
    final taskID = _taskID;
    final format = _videoFormat;
    if (taskID == null || format == null || frame.points.isEmpty) {
      return;
    }

    final videoSize = Size(format.width.toDouble(), format.height.toDouble());
    final points = frame.points
        .map(
          (point) => InteractionCoordinateMapper.map(
            point: point,
            viewportSize: frame.viewportSize,
            videoSize: videoSize,
            contentMode: frame.contentMode,
          ),
        )
        .whereType<RealtimePoint>()
        .toList(growable: false);

    if (points.isEmpty) {
      return;
    }

    // Keep only the latest unsent frame to avoid an unbounded touch backlog.
    _pendingPoints = points;

    if (!_draining) {
      unawaited(_drain(taskID));
    }
  }

  Future<void> _drain(String taskID) async {
    _draining = true;
    try {
      while (_taskID == taskID && _pendingPoints != null) {
        final points = _pendingPoints!;
        _pendingPoints = null;

        try {
          await _listener(taskID, points);
        } catch (_) {}
      }
    } finally {
      _draining = false;

      if (_taskID != null && _pendingPoints != null) {
        unawaited(_drain(_taskID!));
      }
    }
  }
}
