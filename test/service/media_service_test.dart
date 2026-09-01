import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/service/media/MediaService.dart';
import 'package:xmax_sdk/XmaxSDK.dart';

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
}
