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
      XmaxLogger.debug(message, category: 'API');
    } else {
      XmaxLogger.error(message, category: 'API');
    }
  }

  static void logFailure({
    required ApiMethod method,
    required String path,
    required Object error,
    required int durationMs,
  }) {
    XmaxLogger.error(
      '${method.value} $path 失败 (Request Failed)\n'
      '├─ 耗时：$durationMs ms\n'
      '└─ 原因：${_errorMessage(error)}',
      category: 'API',
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

  static String _errorMessage(Object error) {
    final message = error.toString().trim();
    return message.isEmpty ? error.runtimeType.toString() : message;
  }
}
