import '../../foundation/errors/ErrorMessageFormatter.dart';
import '../../foundation/errors/XmaxError.dart';
import '../../foundation/logging/XmaxLogger.dart';
import '../../service/realtime/RealtimeError.dart';

final class RealtimeErrorHandler {
  RealtimeErrorListener? _failureHandler;

  void setFailureHandler(RealtimeErrorListener? handler) {
    _failureHandler = handler;
  }

  XmaxError report(Object error) {
    final xmaxError = XmaxError.from(error);
    _log(xmaxError);
    return xmaxError;
  }

  void forward(XmaxError error) {
    _log(error);
    _failureHandler?.call(error);
  }

  void _log(XmaxError error) {
    try {
      XmaxLogger.error(
        category: XmaxLoggerCategory.realtime,
        message:
            '实时操作失败 (Realtime Operation Failed)\n'
            '└─ ${XmaxLogger.localized('原因：', 'Reason: ')}${ErrorMessageFormatter.format(error)}',
      );
    } catch (_) {
      // A diagnostic sink must not prevent delivery of the original error.
    }
  }
}
