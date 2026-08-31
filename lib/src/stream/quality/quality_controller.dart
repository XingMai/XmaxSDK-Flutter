import '../../service/realtime/realtime_network_quality.dart';
import '../../service/realtime/realtime_performance_alarm.dart';
import 'quality_controlling.dart';

final class QualityController implements QualityControlling {
  RealtimeNetworkQualityListener? _networkQualityListener;
  RealtimePerformanceAlarmListener? _performanceAlarmListener;

  @override
  void setNetworkQualityListener(RealtimeNetworkQualityListener? listener) {
    _networkQualityListener = listener;
  }

  @override
  void setPerformanceAlarmListener(RealtimePerformanceAlarmListener? listener) {
    _performanceAlarmListener = listener;
  }

  @override
  void emitNetworkQuality(RealtimeNetworkQuality quality) {
    _networkQualityListener?.call(quality);
  }

  @override
  void emitPerformanceAlarm(RealtimePerformanceAlarm alarm) {
    _performanceAlarmListener?.call(alarm);
  }
}
