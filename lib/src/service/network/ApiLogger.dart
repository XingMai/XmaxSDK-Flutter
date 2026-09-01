import '../../foundation/errors/ErrorMessageFormatter.dart';
import '../../foundation/logging/XmaxLogger.dart';
import 'ApiServicing.dart';

abstract final class ApiLogger {
  static void logResponse({
    required ApiMethod method,
    required String path,
    required int statusCode,
    required int bodyByteCount,
    required int durationMs,
    required bool successful,
  }) {
    final message = responseMessage(
      method: method,
      path: path,
      statusCode: statusCode,
      bodyByteCount: bodyByteCount,
      durationMs: durationMs,
    );
    if (successful) {
      XmaxLogger.debug(category: XmaxLoggerCategory.api, message: message);
    } else {
      XmaxLogger.error(category: XmaxLoggerCategory.api, message: message);
    }
  }

  static void logFailure({
    required ApiMethod method,
    required String path,
    required Object error,
    required int durationMs,
  }) {
    XmaxLogger.error(
      category: XmaxLoggerCategory.api,
      message:
          '${method.value} $path 失败 (Request Failed)\n'
          '├─ 耗时：$durationMs ms\n'
          '└─ 原因：${ErrorMessageFormatter.format(error)}',
    );
  }

  static String responseMessage({
    required ApiMethod method,
    required String path,
    required int statusCode,
    required int bodyByteCount,
    required int durationMs,
  }) =>
      '${method.value} $path\n'
      '├─ 状态：$statusCode\n'
      '├─ 耗时：$durationMs ms\n'
      '└─ 响应：$bodyByteCount bytes';
}
