import 'dart:async';

import 'package:volc_engine_rtc/volc_engine_rtc.dart';

import '../errors/XmaxError.dart';

final class RtcEngineLease {
  RtcEngineLease(this.engine);

  final RTCEngine engine;
  final Object id = Object();
}

final class RtcEngineManager {
  RtcEngineManager._() : _createEngine = _createNativeEngine;

  RtcEngineManager.internal({
    required Future<RTCEngine> Function() createEngine,
  }) : _createEngine = createEngine;

  static final shared = RtcEngineManager._();
  static const defaultAppID = '69a177e226e9b90176a86b96';

  final Future<RTCEngine> Function() _createEngine;

  static Future<RTCEngine> _createNativeEngine() =>
      RTCEngine.createRTCEngine(RTCVideoContext(appId: defaultAppID));

  RtcEngineLease? _activeLease;
  final List<Completer<RtcEngineLease>> _requests =
      <Completer<RtcEngineLease>>[];

  Future<RtcEngineLease> acquire() async {
    if (_activeLease == null && _requests.isEmpty) {
      final lease = await _createLease();
      _activeLease = lease;
      return lease;
    }
    final completer = Completer<RtcEngineLease>();
    _requests.add(completer);
    return completer.future;
  }

  Future<void> release(RtcEngineLease lease) async {
    if (!identical(_activeLease?.id, lease.id)) {
      return;
    }
    try {
      lease.engine.destroy();
    } finally {
      // A failed native release must not retain ownership and block all future
      // managers queued for the shared engine.
      _activeLease = null;
      await _fulfillNext();
    }
  }

  Future<RtcEngineLease> _createLease() async {
    try {
      final engine = await _createEngine();
      return RtcEngineLease(engine);
    } catch (error) {
      throw XmaxError(
        code: XmaxErrorCode.rtcError,
        message: 'Failed to create RTC Engine: $error',
      );
    }
  }

  Future<void> _fulfillNext() async {
    while (_activeLease == null && _requests.isNotEmpty) {
      final request = _requests.removeAt(0);
      try {
        final lease = await _createLease();
        _activeLease = lease;
        request.complete(lease);
      } catch (error, stackTrace) {
        request.completeError(error, stackTrace);
      }
    }
  }
}
