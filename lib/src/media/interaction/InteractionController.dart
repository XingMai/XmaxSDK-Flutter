import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../foundation/logging/XmaxLogger.dart';
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
  int _drainGeneration = 0;

  @override
  void startInteraction({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
  }) {
    _cancelPendingFrames();
    _taskID = taskID;
    _videoFormat = videoFormat;
  }

  @override
  void stopInteraction() {
    _taskID = null;
    _videoFormat = null;
    _cancelPendingFrames();
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
      unawaited(_drain(_drainGeneration));
    }
  }

  void _cancelPendingFrames() {
    // Dart cannot retract an already submitted RTC message. Invalidate the
    // old drain instead, so a new task starts immediately and late completion
    // cannot consume its points or clear its sending flag (even for the same ID).
    _drainGeneration += 1;
    _pendingPoints = null;
    _draining = false;
  }

  Future<void> _drain(int generation) async {
    _draining = true;
    try {
      while (generation == _drainGeneration &&
          _taskID != null &&
          _pendingPoints != null) {
        final taskID = _taskID!;
        final points = _pendingPoints!;
        _pendingPoints = null;

        try {
          await _listener(taskID, points);
        } catch (error) {
          if (generation != _drainGeneration) return;
          XmaxLogger.warn(
            category: XmaxLoggerCategory.interaction,
            message:
                '发送交互轨迹失败，已丢弃当前采样帧 '
                '(Failed to Send Interaction Trajectory; Current Sample Dropped)\n'
                '└─ ${XmaxLogger.localized('原因：', 'Reason: ')}$error',
          );
        }
      }
    } finally {
      if (generation == _drainGeneration) {
        _draining = false;
        if (_taskID != null && _pendingPoints != null) {
          unawaited(_drain(generation));
        }
      }
    }
  }
}
