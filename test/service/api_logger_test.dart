import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/foundation/logging/XmaxLogger.dart';
import 'package:xmax_sdk/src/foundation/logging/XmaxLoggerOption.dart';
import 'package:xmax_sdk/src/service/network/ApiLogger.dart';
import 'package:xmax_sdk/src/service/network/ApiServicing.dart';

void main() {
  late List<({XmaxLogLevel level, String message})> records;

  setUp(() {
    XmaxLogger.reset();
    XmaxLogger.configure(options: XmaxLoggerOption.business);
    records = <({XmaxLogLevel level, String message})>[];
    XmaxLogger.setSink((level, message) {
      records.add((level: level, message: message));
    });
  });

  tearDown(XmaxLogger.reset);

  test('responseMessage matches the iOS layout', () {
    expect(
      ApiLogger.responseMessage(
        method: ApiMethod.post,
        path: '/session',
        statusCode: 201,
        bodyByteCount: 128,
        durationMs: 42,
      ),
      'POST /session\n'
      '├─ 状态：201\n'
      '├─ 耗时：42 ms\n'
      '└─ 响应：128 bytes',
    );
  });

  test('successful and failed responses preserve log levels', () {
    ApiLogger.logResponse(
      method: ApiMethod.get,
      path: '/session',
      statusCode: 200,
      bodyByteCount: 64,
      durationMs: 12,
      successful: true,
    );
    ApiLogger.logResponse(
      method: ApiMethod.get,
      path: '/session',
      statusCode: 500,
      bodyByteCount: 32,
      durationMs: 18,
      successful: false,
    );

    expect(records.map((record) => record.level), <XmaxLogLevel>[
      XmaxLogLevel.debug,
      XmaxLogLevel.error,
    ]);
    expect(records.last.message, contains('[Xmax][API] └─ 响应：32 bytes'));
  });

  test('transport failure matches the iOS layout', () {
    ApiLogger.logFailure(
      method: ApiMethod.delete,
      path: '/session/1',
      error: StateError('offline'),
      durationMs: 15,
    );

    expect(records.single.level, XmaxLogLevel.error);
    expect(
      records.single.message,
      '[Xmax][API] DELETE /session/1 失败 (Request Failed)\n'
      '[Xmax][API] ├─ 耗时：15 ms\n'
      '[Xmax][API] └─ 原因：Bad state: offline',
    );
  });
}
