import 'package:flutter/widgets.dart';

final class TrajectoryID {
  TrajectoryID._(this.rawValue);

  final int rawValue;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrajectoryID && rawValue == other.rawValue;

  @override
  int get hashCode => rawValue.hashCode;
}

final class TrajectoryPoint {
  const TrajectoryPoint({
    required this.id,
    required this.location,
    required this.normalizedLocation,
    required this.timestamp,
  });

  final TrajectoryID id;
  final Offset location;
  final Offset normalizedLocation;
  final Duration timestamp;
}

abstract interface class TrajectoryEffectRendering {
  Widget get view;
  void renderBegan(List<TrajectoryPoint> points);
  void renderMoved(List<TrajectoryPoint> points);
  void renderEnded(List<TrajectoryID> identifiers);
  void reset();
}

TrajectoryID createTrajectoryID(int rawValue) => TrajectoryID._(rawValue);
