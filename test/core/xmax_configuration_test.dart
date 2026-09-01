import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/XmaxSDK.dart';

void main() {
  test('XmaxConfiguration trims and validates API key', () {
    final configuration = XmaxConfiguration(apiKey: '  key-123 \n');

    expect(configuration.apiKey, 'key-123');
    expect(configuration.validate, returnsNormally);
  });

  test('XmaxConfiguration rejects an empty API key', () {
    final configuration = XmaxConfiguration(apiKey: ' \n ');

    expect(
      configuration.validate,
      throwsA(
        isA<XmaxError>()
            .having((error) => error.code, 'code', XmaxErrorCode.invalidAPIKey)
            .having(
              (error) => error.message,
              'message',
              'API key cannot be empty',
            ),
      ),
    );
  });

  test('XmaxLoggerOption keeps iOS bit values', () {
    expect(XmaxLoggerOption.business.rawValue, 1);
    expect(XmaxLoggerOption.performance.rawValue, 2);
    expect(XmaxLoggerOption.all.rawValue, 3);
    expect(
      (XmaxLoggerOption.business | XmaxLoggerOption.performance),
      XmaxLoggerOption.all,
    );
  });
}
