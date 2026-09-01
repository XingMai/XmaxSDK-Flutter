import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/XmaxSDK.dart';

void main() {
  test('public enum values match iOS raw values', () {
    expect(RealtimeModel.x2_0.value, 'x2.0');
    expect(CameraPosition.front.value, 'front');
    expect(VideoContentMode.fill.value, 'fill');
    expect(RealtimeConnectionState.generating.value, 'Generating');
    expect(RealtimeNetworkQualityLevel.veryBad.value, 'VeryBad');
    expect(RealtimePerformanceStatus.recovered.value, 'Recovered');
    expect(XmaxErrorCode.unsafeImage.value, 'UNSAFE_IMAGE');
  });

  test('RealtimeContext normalizes prompt and reference path', () {
    expect(
      RealtimeContext(prompt: '  dress  ', referencePath: '  /image.png  '),
      RealtimeContext(prompt: 'dress', referencePath: '/image.png'),
    );
    expect(
      RealtimeContext(prompt: 'test', referencePath: ' ').referencePath,
      isNull,
    );
  });

  test('RealtimeVideoFormat validates positive even dimensions and fps', () {
    expect(
      const RealtimeVideoFormat(width: 768, height: 1024, fps: 24).validate,
      returnsNormally,
    );

    for (final format in <RealtimeVideoFormat>[
      const RealtimeVideoFormat(width: 0, height: 1024, fps: 24),
      const RealtimeVideoFormat(width: 767, height: 1024, fps: 24),
      const RealtimeVideoFormat(width: 768, height: 1023, fps: 24),
      const RealtimeVideoFormat(width: 768, height: 1024, fps: 0),
    ]) {
      expect(
        format.validate,
        throwsA(
          isA<XmaxError>().having(
            (error) => error.code,
            'code',
            XmaxErrorCode.invalidConfiguration,
          ),
        ),
      );
    }
  });
}
