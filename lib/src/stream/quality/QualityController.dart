import '../../service/realtime/RealtimeNetworkQuality.dart';
import '../../service/realtime/RealtimePerformanceAlarm.dart';
import 'QualityControlling.dart';

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
