import 'realtime_video_format.dart';

enum RealtimePerformanceStatus {
  limited('Limited'),
  recovered('Recovered');

  const RealtimePerformanceStatus(this.value);

  final String value;
}

final class RealtimePerformanceAlarm {
  const RealtimePerformanceAlarm({
    required this.status,
    this.suggestedVideoFormat,
  });

  final RealtimePerformanceStatus status;
  final RealtimeVideoFormat? suggestedVideoFormat;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RealtimePerformanceAlarm &&
          status == other.status &&
          suggestedVideoFormat == other.suggestedVideoFormat;

  @override
  int get hashCode => Object.hash(status, suggestedVideoFormat);
}

typedef RealtimePerformanceAlarmListener =
    void Function(RealtimePerformanceAlarm alarm);
