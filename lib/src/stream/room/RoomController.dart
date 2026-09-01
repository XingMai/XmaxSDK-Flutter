import '../../foundation/errors/XmaxError.dart';
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
  }) => _rtcManager.sendRoomMessage(
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
  }) => _rtcManager.sendRoomMessage(
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
    await _rtcManager.sendRoomMessage(
      RoomEvent.stop(userID: userID, taskID: taskID),
    );
  }

  @override
  Future<void> sendTracks({
    required String taskID,
    required List<RealtimePoint> points,
  }) async {
    if (taskID.isEmpty || points.isEmpty) {
      return;
    }
    await _rtcManager.sendRoomMessage(
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
}
