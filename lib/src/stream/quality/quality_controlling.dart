import '../../service/realtime/realtime_network_quality.dart';
import '../../service/realtime/realtime_performance_alarm.dart';

abstract interface class QualityControlling {
  void setNetworkQualityListener(RealtimeNetworkQualityListener? listener);
  void setPerformanceAlarmListener(RealtimePerformanceAlarmListener? listener);
  void emitNetworkQuality(RealtimeNetworkQuality quality);
  void emitPerformanceAlarm(RealtimePerformanceAlarm alarm);
}
