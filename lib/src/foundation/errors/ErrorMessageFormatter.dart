import 'ErrorNormalizer.dart';
import 'XmaxError.dart';

/// 将 SDK、系统和第三方错误转换为适合日志及调试界面展示的文本。
abstract final class ErrorMessageFormatter {
  static String format(Object error) {
    if (error is XmaxError) {
      final apiCode = error.apiCode == null ? '' : '，业务码 ${error.apiCode}';
      final httpStatus = error.httpStatus == null
          ? ''
          : '，HTTP ${error.httpStatus}';
      return '${error.message}（${error.code.value}$apiCode$httpStatus）';
    }

    final message = ErrorNormalizer.description(error);
    final platformCode = ErrorNormalizer.platformErrorCode(error);
    return platformCode == null ? message : '$message（平台错误码：$platformCode）';
  }
}
