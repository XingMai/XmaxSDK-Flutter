import 'package:flutter_test/flutter_test.dart';
import 'package:volc_engine_rtc/volc_engine_rtc.dart';
import 'package:xmax_sdk/src/core/XmaxEnvironment.dart';
import 'package:xmax_sdk/src/foundation/logging/XmaxLogger.dart';
import 'package:xmax_sdk/src/foundation/logging/XmaxLoggerOption.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcStatsLogger.dart';

void main() {
  setUp(XmaxLogger.reset);
  tearDown(XmaxLogger.reset);

  test('global performance details use the iOS English terminology', () {
    XmaxLogger.configure(
      options: XmaxLoggerOption.all,
      environment: XmaxEnvironment.global,
    );
    expect(
      RtcStatsLogger.networkQualityName(
        NetworkQuality.NETWORK_QUALITY_VERY_BAD,
      ),
      'Very Bad',
    );
    expect(
      RtcStatsLogger.networkQualityName(
        NetworkQuality.ByteRTCNetworkQualityExcellent,
      ),
      'Excellent',
    );
    expect(
      RtcStatsLogger.performanceAlarmName(
        PerformanceAlarmReason.bandwidth_fallbacked,
      ),
      'Bandwidth Limited',
    );
    expect(
      RtcStatsLogger.performanceAlarmName(
        PerformanceAlarmReason.ByteRTCPerformanceAlarmReasonResumed,
      ),
      'Device Performance Recovered',
    );
    final messages = <String>[];
    XmaxLogger.setSink((_, message) => messages.add(message));
    RtcStatsLogger.logPerformanceAlarm(
      PerformanceAlarmReason.bandwidth_fallbacked,
      _WantedData(),
    );
    expect(messages.single, contains('性能告警 (Performance Alert)'));
    expect(messages.single, contains('├─ Status: Bandwidth Limited'));
    expect(messages.single, contains('└─ Recommendation: 832 × 1472, 30 fps'));
    XmaxLogger.configure(
      options: XmaxLoggerOption.business,
      environment: XmaxEnvironment.global,
    );
    RtcStatsLogger.logPerformanceAlarm(
      PerformanceAlarmReason.bandwidth_fallbacked,
      _WantedData(),
    );
    expect(
      messages,
      hasLength(1),
      reason: 'Language does not affect filtering',
    );
  });
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

class _WantedData implements SourceWantedData {
  @override
  int get width => 832;
  @override
  int get height => 1472;
  @override
  int get frameRate => 30;
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
