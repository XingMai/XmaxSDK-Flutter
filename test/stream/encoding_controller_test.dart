import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/foundation/errors/XmaxError.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcManaging.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcModels.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeVideoFormat.dart';
import 'package:xmax_sdk/src/stream/encoding/EncodingController.dart';

void main() {
  test('iOS bitrate reference values and X2.0 Pro defaults match', () async {
    final rtc = _FakeRtc();
    final controller = EncodingController(rtcManager: rtc);
    final cases = <(RealtimeVideoFormat, int, int)>[
      (
        const RealtimeVideoFormat(width: 1920, height: 1080, fps: 30),
        3150,
        6300,
      ),
      (
        const RealtimeVideoFormat(width: 1920, height: 1080, fps: 24),
        2722,
        5444,
      ),
      (
        const RealtimeVideoFormat(width: 832, height: 1472, fps: 24),
        1805,
        3611,
      ),
      (
        const RealtimeVideoFormat(width: 1024, height: 1920, fps: 30),
        3016,
        6031,
      ),
      (
        const RealtimeVideoFormat(width: 1024, height: 1920, fps: 24),
        2606,
        5212,
      ),
      (
        const RealtimeVideoFormat(width: 1024, height: 768, fps: 30),
        1516,
        3033,
      ),
      (
        const RealtimeVideoFormat(width: 3840, height: 2160, fps: 30),
        12600,
        25200,
      ),
      (const RealtimeVideoFormat(width: 120, height: 120, fps: 30), 77, 154),
      (const RealtimeVideoFormat(width: 2, height: 2, fps: 1), 1, 2),
    ];

    for (final (format, minimum, maximum) in cases) {
      await controller.configure(format);
      expect(rtc.configuration?.minimumBitrate, minimum, reason: '$format');
      expect(rtc.configuration?.maximumBitrate, maximum, reason: '$format');
      expect(
        rtc.configuration?.encoderPreference,
        RealtimeVideoEncoderPreference.auto,
      );
    }
  });

  test('explicit bitrate bounds and encoder preference reach RTC', () async {
    final rtc = _FakeRtc();
    final controller = EncodingController(rtcManager: rtc);

    await controller.configure(
      const RealtimeVideoFormat(
        width: 832,
        height: 1472,
        fps: 24,
        minimumBitrate: 1500,
        maximumBitrate: 3000,
        encoderPreference: RealtimeVideoEncoderPreference.maintainQuality,
      ),
    );
    expect(rtc.configuration?.minimumBitrate, 1500);
    expect(rtc.configuration?.maximumBitrate, 3000);
    expect(
      rtc.configuration?.encoderPreference,
      RealtimeVideoEncoderPreference.maintainQuality,
    );

    await controller.configure(
      const RealtimeVideoFormat(
        width: 832,
        height: 1472,
        fps: 24,
        maximumBitrate: 4000,
        encoderPreference: RealtimeVideoEncoderPreference.maintainFramerate,
      ),
    );
    expect(rtc.configuration?.minimumBitrate, 1805);
    expect(rtc.configuration?.maximumBitrate, 4000);
    expect(
      rtc.configuration?.encoderPreference,
      RealtimeVideoEncoderPreference.maintainFramerate,
    );

    await controller.configure(
      const RealtimeVideoFormat(
        width: 832,
        height: 1472,
        fps: 24,
        minimumBitrate: 1500,
      ),
    );
    expect(rtc.configuration?.minimumBitrate, 1500);
    expect(rtc.configuration?.maximumBitrate, 3611);

    await controller.configure(
      const RealtimeVideoFormat(
        width: 832,
        height: 1472,
        fps: 24,
        minimumBitrate: 0,
        maximumBitrate: 500,
      ),
    );
    expect(rtc.configuration?.minimumBitrate, 0);
    expect(rtc.configuration?.maximumBitrate, 500);

    await controller.configure(
      const RealtimeVideoFormat(
        width: 832,
        height: 1472,
        fps: 24,
        minimumBitrate: 2000,
        maximumBitrate: 2000,
      ),
    );
    expect(rtc.configuration?.minimumBitrate, 2000);
    expect(rtc.configuration?.maximumBitrate, 2000);
  });

  test('invalid explicit or default-merged bounds never reach RTC', () async {
    final rtc = _FakeRtc();
    final controller = EncodingController(rtcManager: rtc);

    for (final format in <RealtimeVideoFormat>[
      const RealtimeVideoFormat(
        width: 832,
        height: 1472,
        fps: 24,
        minimumBitrate: -1,
      ),
      const RealtimeVideoFormat(
        width: 832,
        height: 1472,
        fps: 24,
        maximumBitrate: 0,
      ),
      const RealtimeVideoFormat(
        width: 832,
        height: 1472,
        fps: 24,
        minimumBitrate: 3000,
        maximumBitrate: 1500,
      ),
      const RealtimeVideoFormat(
        width: 832,
        height: 1472,
        fps: 24,
        minimumBitrate: 4000,
      ),
      const RealtimeVideoFormat(
        width: 832,
        height: 1472,
        fps: 24,
        maximumBitrate: 1000,
      ),
      const RealtimeVideoFormat(
        width: 1099511627776,
        height: 1099511627776,
        fps: 60,
      ),
    ]) {
      await expectLater(
        controller.configure(format),
        throwsA(
          isA<XmaxError>().having(
            (error) => error.code,
            'code',
            XmaxErrorCode.invalidConfiguration,
          ),
        ),
      );
      expect(rtc.configuration, isNull);
    }
  });
}

final class _FakeRtc implements RtcManaging {
  VideoEncodingConfiguration? configuration;

  @override
  Future<void> configureVideoEncoding(
    VideoEncodingConfiguration configuration,
  ) async {
    this.configuration = configuration;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
