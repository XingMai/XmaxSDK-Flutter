import 'dart:async';
import 'dart:convert';

import '../../core/realtime/RealtimeModel.dart';
import '../../foundation/errors/XmaxError.dart';
import '../network/ApiServicing.dart';
import 'RealtimeSession.dart';
import 'RealtimeSessionServicing.dart';

final class RealtimeSessionService implements RealtimeSessionServicing {
  RealtimeSessionService({
    required ApiServicing apiService,
    Duration heartbeatInterval = const Duration(seconds: 10),
  }) : _apiService = apiService,
       _heartbeatInterval = heartbeatInterval;

  final ApiServicing _apiService;
  final Duration _heartbeatInterval;
  int _heartbeatVersion = 0;
  Timer? _heartbeatTimer;

  @override
  Future<RealtimeSession> createSession({required RealtimeModel model}) async {
    final payload = await _apiService.post<Map<String, dynamic>>(
      '/session',
      _map,
      body: <String, Object?>{'model': model.value},
    );
    return _makeSession(payload, requiresConnection: true);
  }

  @override
  void startHeartbeat({
    required String sessionID,
    required RealtimeSessionHeartbeatFailureHandler onFailure,
  }) {
    stopHeartbeat();

    // The version prevents a cancelled timer/request from rescheduling itself.
    final version = ++_heartbeatVersion;
    _heartbeatTimer = Timer(_heartbeatInterval, () {
      unawaited(_heartbeat(sessionID, version, onFailure));
    });
  }

  @override
  void stopHeartbeat() {
    _heartbeatVersion += 1;
    _heartbeatTimer?.cancel();
    _heartbeatTimer = null;
  }

  @override
  Future<void> closeSession({required String sessionID}) async {
    await _apiService.delete<Map<String, dynamic>>('/session/$sessionID', _map);
  }

  Future<void> _heartbeat(
    String sessionID,
    int version,
    RealtimeSessionHeartbeatFailureHandler onFailure,
  ) async {
    if (version != _heartbeatVersion) {
      return;
    }

    try {
      final payload = await _apiService.put<Map<String, dynamic>>(
        '/session/$sessionID/heartbeat',
        _map,
      );

      if (version != _heartbeatVersion) {
        return;
      }

      final session = _makeSession(payload, requiresConnection: false);
      if (session.status != null && session.status != 'ACTIVE') {
        throw XmaxError(
          code: XmaxErrorCode.sessionError,
          message:
              session.closeReason ??
              'Session is no longer active: ${session.status}',
        );
      }

      _heartbeatTimer = Timer(_heartbeatInterval, () {
        unawaited(_heartbeat(sessionID, version, onFailure));
      });
    } catch (error) {
      if (version != _heartbeatVersion) {
        return;
      }

      _heartbeatVersion += 1;
      _heartbeatTimer = null;
      await onFailure(sessionID, error);
    }
  }

  RealtimeSession _makeSession(
    Map<String, dynamic> payload, {
    required bool requiresConnection,
  }) {
    final sessionID = _nonEmpty(payload['sessionUid']);
    if (sessionID == null) {
      throw const XmaxError(
        code: XmaxErrorCode.sessionError,
        message: 'Invalid session response',
      );
    }

    final userID = _nonEmpty(payload['userUid']);
    final connection = _makeConnection(payload['modelExtra'], userID);

    if (requiresConnection && connection == null) {
      throw const XmaxError(
        code: XmaxErrorCode.sessionError,
        message: 'Session does not contain complete RTC join information',
      );
    }

    return RealtimeSession(
      id: sessionID,
      userID: userID,
      status: _nonEmpty(payload['status']),
      connection: connection,
      closeReason: _nonEmpty(payload['closeReason']),
    );
  }

  RealtimeSessionConnection? _makeConnection(
    Object? modelExtra,
    String? fallbackUserID,
  ) {
    Object? value = modelExtra;
    if (value is String) {
      try {
        value = jsonDecode(value);
      } catch (_) {
        return null;
      }
    }

    if (value is! Map) {
      return null;
    }

    final roomID = _nonEmpty(value['room_id']);
    final token = _nonEmpty(value['room_token']);
    final userID = _nonEmpty(value['user_id']) ?? fallbackUserID;

    if (roomID == null || token == null || userID == null) {
      return null;
    }

    return RealtimeSessionConnection(
      roomID: roomID,
      userID: userID,
      token: token,
      botName: _nonEmpty(value['bot_name']),
    );
  }

  static Map<String, dynamic> _map(Object? json) =>
      Map<String, dynamic>.from(json! as Map);

  static String? _nonEmpty(Object? value) {
    final normalized = value is String ? value.trim() : null;
    return normalized == null || normalized.isEmpty ? null : normalized;
  }
}
