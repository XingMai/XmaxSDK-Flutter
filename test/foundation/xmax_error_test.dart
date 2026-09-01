import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/foundation/errors/ErrorMessageFormatter.dart';
import 'package:xmax_sdk/src/foundation/errors/XmaxError.dart';

void main() {
  test('from preserves XmaxError and normalizes platform descriptions', () {
    const existing = XmaxError(
      code: XmaxErrorCode.apiError,
      message: 'denied',
      apiCode: 4001,
      httpStatus: 403,
    );

    expect(XmaxError.from(existing), same(existing));
    expect(
      XmaxError.from(const HttpException('  offline  ')),
      const XmaxError(code: XmaxErrorCode.internalError, message: 'offline'),
    );
  });

  test('formatter keeps SDK and platform diagnostic codes', () {
    expect(
      ErrorMessageFormatter.format(
        const XmaxError(
          code: XmaxErrorCode.apiError,
          message: 'denied',
          apiCode: 4001,
          httpStatus: 403,
        ),
      ),
      'denied（API_ERROR，业务码 4001，HTTP 403）',
    );
    expect(
      ErrorMessageFormatter.format(
        const SocketException('offline', osError: OSError('failed', 57)),
      ),
      'offline（平台错误码：57）',
    );
  });
}
