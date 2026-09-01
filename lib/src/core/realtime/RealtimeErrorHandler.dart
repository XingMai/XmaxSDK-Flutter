import '../../foundation/errors/ErrorMessageFormatter.dart';
import '../../foundation/errors/XmaxError.dart';
import '../../foundation/logging/XmaxLogger.dart';
import '../../service/realtime/RealtimeError.dart';

final class RealtimeErrorHandler {
  RealtimeErrorListener? _listener;

  void setListener(RealtimeErrorListener? listener) {
    _listener = listener;
  }

  XmaxError report(Object error) {
    final xmaxError = XmaxError.from(error);
    _notify(xmaxError);
    return xmaxError;
  }

  void forward(XmaxError error) {
    _notify(error);
  }

  void _notify(XmaxError error) {
    try {
      _listener?.call(error);
    } catch (listenerError) {
      try {
        XmaxLogger.error(
          category: XmaxLoggerCategory.realtime,
          message:
              '错误监听器执行失败 (Error Listener Failed)\n'
              '└─ 原因：${ErrorMessageFormatter.format(listenerError)}',
        );
      } catch (_) {
        // Listener and diagnostic failures must never replace the SDK error.
      }
    }
  }
}
