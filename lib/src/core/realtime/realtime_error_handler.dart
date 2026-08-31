import '../../foundation/errors/xmax_error.dart';
import '../../service/realtime/realtime_error.dart';

final class RealtimeErrorHandler {
  RealtimeErrorListener? _listener;

  void setListener(RealtimeErrorListener? listener) {
    _listener = listener;
  }

  XmaxError report(Object error) {
    final xmaxError = XmaxError.from(error);
    _listener?.call(xmaxError);
    return xmaxError;
  }

  void forward(XmaxError error) {
    _listener?.call(error);
  }
}
