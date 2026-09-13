import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/xmax_sdk.dart';

void main() {
  test('public enum values match iOS raw values', () {
    expect(RealtimeModel.x2_0.value, 'x2.0');
    expect(RealtimeModel.x2_0_pro.value, 'x2.0-pro');
    expect(CameraPosition.front.value, 'front');
    expect(VideoContentMode.fill.value, 'fill');
    expect(RealtimeConnectionState.generating.value, 'Generating');
    expect(RealtimeNetworkQualityLevel.veryBad.value, 'VeryBad');
    expect(RealtimePerformanceStatus.recovered.value, 'Recovered');
    expect(XmaxErrorCode.unsafeImage.value, 'UNSAFE_IMAGE');
  });

  test('RealtimeModel follows iOS input and camera defaults', () {
    expect(RealtimeModel.values, <RealtimeModel>[
      RealtimeModel.x2_0,
      RealtimeModel.x2_0_pro,
    ]);
    expect(RealtimeModel.x2_0.resolutionBuckets, isEmpty);
    expect(RealtimeModel.x2_0_pro.resolutionBuckets, const <Size>[
      Size(1024, 1920),
      Size(1920, 1024),
    ]);
    expect(RealtimeModel.x2_0.minimumInputPixels, 600000);
    expect(RealtimeModel.x2_0.maximumInputPixels, 1280000);
    expect(RealtimeModel.x2_0_pro.maximumInputPixels, 2100000);
    expect(RealtimeModel.x2_0.inputSizeAlignment, 32);
    expect(RealtimeModel.x2_0.defaultFrameRate, 30);
    expect(RealtimeModel.x2_0_pro.defaultFrameRate, 30);
    expect(
      RealtimeModel.x2_0.defaultCameraVideoFormat,
      const RealtimeVideoFormat(width: 832, height: 1472, fps: 30),
    );
    expect(
      RealtimeModel.x2_0_pro.defaultCameraVideoFormat,
      const RealtimeVideoFormat(width: 1024, height: 1920, fps: 30),
    );
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
