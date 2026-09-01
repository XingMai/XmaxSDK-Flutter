import '../../foundation/errors/XmaxError.dart';
import '../../service/realtime/RealtimeError.dart';

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
