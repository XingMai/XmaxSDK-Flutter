import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/service/media/MediaService.dart';
import 'package:xmax_sdk/xmax_sdk.dart';

void main() {
  final service = MediaService();

  test('resolveModelInputSize aligns a model-sized input to 32 pixels', () {
    expect(
      service.resolveModelInputSize(const Size(768, 1024)),
      const Size(768, 1024),
    );
  });

  test('resolveModelInputSize scales small and large inputs', () {
    expect(
      service.resolveModelInputSize(const Size(320, 240)),
      const Size(896, 672),
    );
    expect(
      service.resolveModelInputSize(const Size(3840, 2160)),
      const Size(1504, 832),
    );
  });

  test('resolveModelInputSize rejects invalid dimensions', () {
    expect(
      () => service.resolveModelInputSize(const Size(double.nan, 100)),
      throwsA(
        isA<XmaxError>().having(
          (error) => error.code,
          'code',
          XmaxErrorCode.invalidConfiguration,
        ),
      ),
    );
  });

  test('x2.0-pro accepts only the two iOS resolution buckets', () {
    final pro = MediaService(model: RealtimeModel.x2_0_pro);
    for (final size in const <Size>[Size(1024, 1920), Size(1920, 1024)]) {
      expect(pro.resolveModelInputSize(size), size);
    }

    for (final size in const <Size>[
      Size(832, 1472),
      Size(1920, 1080),
      Size(1024, 1919.9),
      Size(0, 1920),
      Size(double.nan, 1920),
    ]) {
      expect(
        () => pro.resolveModelInputSize(size),
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

  test('client media service uses the requested model', () {
    final client = XmaxClient(
      configuration: XmaxConfiguration(apiKey: 'test-key'),
    );
    expect(
      client.createMediaService().resolveModelInputSize(const Size(832, 1472)),
      const Size(832, 1472),
    );
    expect(
      client
          .createMediaService(model: RealtimeModel.x2_0_pro)
          .resolveModelInputSize(const Size(1024, 1920)),
      const Size(1024, 1920),
    );
  });

  test('x2.0 alignment stays inside its pixel budget', () {
    for (final size in const <Size>[
      Size(799, 751),
      Size(1130, 1130),
      Size(1445, 1445),
      Size(1024, 1920),
      Size(3840, 2160),
      Size(1, 100000),
      Size(100000, 1),
    ]) {
      final resolved = service.resolveModelInputSize(size);
      final pixels = resolved.width * resolved.height;
      expect(resolved.width.toInt() % 32, 0);
      expect(resolved.height.toInt() % 32, 0);
      expect(pixels, greaterThanOrEqualTo(600000));
      expect(pixels, lessThanOrEqualTo(1280000));
    }
  });
}
