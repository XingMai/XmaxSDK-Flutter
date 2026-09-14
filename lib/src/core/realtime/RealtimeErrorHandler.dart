import '../../foundation/errors/ErrorMessageFormatter.dart';
import '../../foundation/errors/XmaxError.dart';
import '../../foundation/logging/XmaxLogger.dart';

enum RealtimeFailureScope { connection, all }

typedef RealtimeFailureHandler =
    Future<void> Function(
      XmaxError error,
      RealtimeFailureScope scope,
      bool Function() isCurrent,
    );

final class RealtimeErrorHandler {
  RealtimeFailureHandler? _failureHandler;
  int _mediaRevision = 0;
  int _connectionRevision = 0;

  void setFailureHandler(RealtimeFailureHandler? handler) {
    _failureHandler = handler;
  }

  /// Media survives a connection reset; replacing media invalidates both scopes.
  void invalidatePendingFailures({
    RealtimeFailureScope scope = RealtimeFailureScope.all,
  }) {
    _connectionRevision += 1;
    if (scope == RealtimeFailureScope.all) _mediaRevision += 1;
  }

  bool Function() captureValidity(RealtimeFailureScope scope) {
    final revision = _revision(scope);
    return () => revision == _revision(scope);
  }

  int _revision(RealtimeFailureScope scope) =>
      scope == RealtimeFailureScope.all ? _mediaRevision : _connectionRevision;

  XmaxError report(Object error) {
    final xmaxError = XmaxError.from(error);
    _log(xmaxError);
    return xmaxError;
  }

  void forward(
    XmaxError error, {
    RealtimeFailureScope scope = RealtimeFailureScope.connection,
  }) {
    final isCurrent = captureValidity(scope);
    final handler = _failureHandler;
    // Capture the originating lifecycle before yielding, then recheck at
    // delivery rather than terminating a newer lifecycle.
    Future<void>.microtask(() async {
      if (!isCurrent()) return;
      _log(error);
      await handler?.call(error, scope, isCurrent);
    }).catchError((Object failure) {
      _log(XmaxError.from(failure));
    });
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
