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
          '├─ ${XmaxLogger.localized('耗时：', 'Duration: ')}$durationMs ms\n'
          '└─ ${XmaxLogger.localized('原因：', 'Reason: ')}${ErrorMessageFormatter.format(error)}',
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
      '├─ ${XmaxLogger.localized('状态：', 'Status: ')}$statusCode\n'
      '├─ ${XmaxLogger.localized('耗时：', 'Duration: ')}$durationMs ms\n'
      '└─ ${XmaxLogger.localized('响应：', 'Response Size: ')}$bodyByteCount bytes';
}
