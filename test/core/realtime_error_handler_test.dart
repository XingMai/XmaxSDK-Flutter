import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/core/realtime/RealtimeErrorHandler.dart';
import 'package:xmax_sdk/src/foundation/errors/XmaxError.dart';
import 'package:xmax_sdk/src/foundation/logging/XmaxLogger.dart';
import 'package:xmax_sdk/src/foundation/logging/XmaxLoggerOption.dart';

void main() {
  setUp(() => XmaxLogger.configure(options: XmaxLoggerOption.all));
  tearDown(XmaxLogger.reset);

  test('generation errors are logged even without an error listener', () {
    final messages = <String>[];
    XmaxLogger.setSink((level, message) {
      expect(level, XmaxLogLevel.error);
      messages.add(message);
    });
    const error = XmaxError(
      code: XmaxErrorCode.timeout,
      message: 'Realtime generation start timed out',
    );

    expect(RealtimeErrorHandler().report(error), same(error));
    expect(messages.single, contains('[Xmax][Realtime]'));
    expect(messages.single, contains(error.message));
  });

  test('a failing diagnostic sink cannot suppress the original error', () {
    XmaxLogger.setSink((_, _) => throw StateError('sink failed'));
    final received = <XmaxError>[];
    final handler = RealtimeErrorHandler()..setFailureHandler(received.add);
    const error = XmaxError(
      code: XmaxErrorCode.timeout,
      message: 'Realtime generation start timed out',
    );

    expect(handler.report(error), same(error));
    expect(
      received,
      isEmpty,
      reason: 'Method failures only throw to their caller',
    );
    handler.forward(error);
    expect(received.single, same(error));
  });
}
