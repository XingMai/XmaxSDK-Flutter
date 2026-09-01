import '../../service/realtime/RealtimeNetworkQuality.dart';
import '../../service/realtime/RealtimePerformanceAlarm.dart';

abstract interface class QualityControlling {
  void setNetworkQualityListener(RealtimeNetworkQualityListener? listener);
  void setPerformanceAlarmListener(RealtimePerformanceAlarmListener? listener);
  void emitNetworkQuality(RealtimeNetworkQuality quality);
  void emitPerformanceAlarm(RealtimePerformanceAlarm alarm);
}
