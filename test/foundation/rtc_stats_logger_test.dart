import 'package:flutter_test/flutter_test.dart';
import 'package:volc_engine_rtc/volc_engine_rtc.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcStatsLogger.dart';

void main() {
  test('percentage formatting matches the iOS logger', () {
    expect(RtcStatsLogger.percentage(0.12345), '12.35%');
  });

  test('network quality names cover Android and iOS enum variants', () {
    expect(
      RtcStatsLogger.networkQualityName(
        NetworkQuality.NETWORK_QUALITY_VERY_BAD,
      ),
      '极差',
    );
    expect(
      RtcStatsLogger.networkQualityName(
        NetworkQuality.ByteRTCNetworkQualityExcellent,
      ),
      '极好',
    );
  });

  test('performance alarm names cover Android and iOS enum variants', () {
    expect(
      RtcStatsLogger.performanceAlarmName(
        PerformanceAlarmReason.bandwidth_fallbacked,
      ),
      '网络受限',
    );
    expect(
      RtcStatsLogger.performanceAlarmName(
        PerformanceAlarmReason.ByteRTCPerformanceAlarmReasonResumed,
      ),
      '设备性能恢复',
    );
  });
}
