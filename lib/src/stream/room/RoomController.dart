import 'dart:convert';

import '../../foundation/errors/XmaxError.dart';
import '../../foundation/logging/XmaxLogger.dart';
import '../../foundation/rtc/RtcManaging.dart';
import '../../foundation/rtc/RtcModels.dart';
import '../../service/realtime/RealtimeContext.dart';
import '../../service/realtime/RealtimePoint.dart';
import '../../service/realtime/RealtimeSession.dart';
import '../../service/realtime/RealtimeVideoFormat.dart';
import 'RoomControlling.dart';
import 'RoomEvent.dart';
import 'RoomHeartbeat.dart';

final class RoomController implements RoomControlling {
  RoomController({required RtcManaging rtcManager, RoomHeartbeat? heartbeat})
    : _rtcManager = rtcManager,
      _heartbeat = heartbeat ?? RoomHeartbeat(rtcManager: rtcManager);

  final RtcManaging _rtcManager;
  final RoomHeartbeat _heartbeat;
  String? _userID;
  bool _joining = false;

  @override
  Future<void> join({
    required RealtimeSessionConnection connection,
    required void Function() ensureActive,
  }) async {
    ensureActive();

    if (_userID != null || _joining) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'Leave the current RTC room before joining another one',
      );
    }

    _joining = true;
    _heartbeat.stop();

    try {
      await _rtcManager.joinRoom(
        configuration: RoomJoinConfiguration(
          roomID: connection.roomID,
          userID: connection.userID,
          token: connection.token,
        ),
      );

      ensureActive();

      _userID = connection.userID;
      _heartbeat.start(userID: connection.userID);
    } catch (error) {
      await _rtcManager.leaveRoom();
      throw XmaxError.from(error);
    } finally {
      _joining = false;
    }
  }

  @override
  Future<void> leave() async {
    // Clear local ownership before awaiting the native room shutdown.
    _userID = null;
    _joining = false;
    _heartbeat.stop();

    await _rtcManager.leaveRoom();
  }

  @override
  Future<void> startGeneration({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
  }) => _send(
    RoomEvent.start(
      userID: _requireUserID(),
      taskID: taskID,
      videoFormat: videoFormat,
      context: context,
    ),
  );

  @override
  Future<void> changeGenerationCondition({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
  }) => _send(
    RoomEvent.changeCondition(
      userID: _requireUserID(),
      taskID: taskID,
      videoFormat: videoFormat,
      context: context,
    ),
  );

  @override
  Future<void> stopGeneration({required String taskID}) async {
    final userID = _userID;
    if (userID == null || taskID.isEmpty) {
      return;
    }

    await _send(RoomEvent.stop(userID: userID, taskID: taskID));
  }

  @override
  Future<void> sendTracks({
    required String taskID,
    required List<RealtimePoint> points,
  }) async {
    if (taskID.isEmpty || points.isEmpty) {
      return;
    }

    await _send(
      RoomEvent.tracks(
        userID: _requireUserID(),
        taskID: taskID,
        points: points,
      ),
    );
  }

  String _requireUserID() {
    final userID = _userID;
    if (userID == null) {
      throw const XmaxError(
        code: XmaxErrorCode.rtcError,
        message: 'RTC room is not joined',
      );
    }

    return userID;
  }

  Future<void> _send(String message) async {
    await _rtcManager.sendRoomMessage(message);
    XmaxLogger.debug(_formatSignalLog(message), category: 'Room');
  }

  static String _formatSignalLog(String message) {
    try {
      final object = jsonDecode(message);
      if (object is! Map<String, dynamic>) {
        throw const FormatException();
      }
      final eventType = object['event'] is String
          ? object['event'] as String
          : 'unknown';
      final formatted = const JsonEncoder.withIndent(
        '  ',
      ).convert(_sortJson(object));
      final indented = formatted.replaceAll('\n', '\n   ');
      return '发送房间信令 (Outbound Room Signaling)\n'
          '├─ 类型：$eventType\n'
          '└─ 内容：\n'
          '   $indented';
    } catch (_) {
      return '发送房间信令 (Outbound Room Signaling)\n└─ 内容：$message';
    }
  }

  static Object? _sortJson(Object? value) {
    if (value is Map) {
      final keys = value.keys.map((key) => key.toString()).toList()..sort();
      return <String, Object?>{
        for (final key in keys) key: _sortJson(value[key]),
      };
    }
    if (value is List) {
      return value.map(_sortJson).toList(growable: false);
    }
    return value;
  }
}
