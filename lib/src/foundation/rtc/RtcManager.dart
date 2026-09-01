import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:volc_engine_rtc/volc_engine_rtc.dart';

import '../../service/realtime/RealtimeNetworkQuality.dart';
import '../../service/realtime/RealtimePerformanceAlarm.dart';
import '../../service/realtime/RealtimeVideoFormat.dart';
import '../errors/XmaxError.dart';
import '../media/camera/CameraPosition.dart';
import 'RtcEngineManager.dart';
import 'RtcEventListener.dart';
import 'RtcManaging.dart';
import 'RtcModels.dart';

final class RtcManager implements RtcManaging {
  RtcManager({RtcEngineManager? engineManager})
    : _engineManager = engineManager ?? RtcEngineManager.shared;

  static const joinTimeout = Duration(seconds: 15);
  static const cleanupTimeout = Duration(seconds: 2);

  final RtcEngineManager _engineManager;
  RtcEngineLease? _lease;
  RTCRoom? _room;
  String _roomID = '';
  RtcEventListener? _eventListener;
  void Function()? _cameraPreviewReadyListener;
  final Map<String, String> _remoteStreamIDs = <String, String>{};

  RTCEngine get _engine {
    final engine = _lease?.engine;
    if (engine == null) {
      throw const XmaxError(
        code: XmaxErrorCode.rtcError,
        message: 'RTC Engine is not initialized',
      );
    }
    return engine;
  }

  @override
  Future<void> initialize() async {
    if (_lease != null) {
      return;
    }

    final lease = await _engineManager.acquire();
    _lease = lease;

    await _check(
      lease.engine.setRTCEngineEventHandler(_makeEngineEventHandler()),
      'setRTCEngineEventHandler',
    );
  }

  @override
  Future<void> destroy() async {
    await leaveRoom();

    final lease = _lease;
    _lease = null;
    _cameraPreviewReadyListener = null;
    _remoteStreamIDs.clear();

    if (lease != null) {
      await _engineManager.release(lease);
    }
  }

  @override
  Future<void> configureVideoEncoding(
    VideoEncodingConfiguration configuration,
  ) async {
    _validateVideoDimensions(
      configuration.width,
      configuration.height,
      configuration.frameRate,
    );
    await _check(
      _engine.setVideoEncoderConfig(
        VideoEncoderConfig(
          width: configuration.width,
          height: configuration.height,
          frameRate: configuration.frameRate,
          maxBitrate: configuration.maximumBitrate,
          minBitrate: configuration.minimumBitrate,
          encoderPreference: VideoEncoderPreference.disabled,
        ),
      ),
      'setVideoEncoderConfig',
    );
  }

  @override
  Future<void> startVideoCapture({
    required int width,
    required int height,
    required int frameRate,
  }) async {
    _validateVideoDimensions(width, height, frameRate);

    await _check(
      _engine.setVideoCaptureConfig(
        VideoCaptureConfig(
          frameRate: frameRate,
          preference: CapturePreference.manual,
          width: width,
          height: height,
        ),
      ),
      'setVideoCaptureConfig',
    );

    await _check(_engine.startVideoCapture(), 'startVideoCapture');
  }

  @override
  Future<void> stopVideoCapture() async {
    final lease = _lease;
    if (lease == null) {
      return;
    }
    await _check(lease.engine.stopVideoCapture(), 'stopVideoCapture');
  }

  @override
  Future<void> switchCamera({required CameraPosition position}) async {
    await _check(
      _engine.switchCamera(
        position == CameraPosition.front ? CameraId.front : CameraId.back,
      ),
      'switchCamera',
    );
    await _check(
      _engine.setLocalVideoMirrorType(
        position == CameraPosition.front ? MirrorType.render : MirrorType.none,
      ),
      'setLocalVideoMirrorType',
    );
  }

  @override
  Future<void> joinRoom({required RoomJoinConfiguration configuration}) async {
    _validateJoinConfiguration(configuration);
    await leaveRoom();

    // Keep a single room instance so stale SDK callbacks can be ignored.
    final room = await _engine.createRTCRoom(configuration.roomID);
    if (room == null) {
      throw const XmaxError(
        code: XmaxErrorCode.rtcError,
        message: 'Failed to create RTC room',
      );
    }

    _room = room;
    _roomID = configuration.roomID;

    final completer = Completer<void>();
    try {
      // Bound the complete native operation, not only the event callback. A
      // stalled platform-channel call must not leave the public Future pending.
      await (() async {
        await _check(
          room.setRTCRoomEventHandler(
            _makeRoomEventHandler(room: room, joinCompleter: completer),
          ),
          'setRTCRoomEventHandler',
        );

        await _check(
          room.joinRoom(
            token: configuration.token,
            userInfo: UserInfo(extraInfo: '', userId: configuration.userID),
            userVisibility: true,
            roomConfig: RoomConfig(
              profile: RoomProfile.communication,
              streamId: configuration.userID,
              isPublishAudio: false,
              isPublishVideo: false,
              isAutoSubscribeAudio: false,
              isAutoSubscribeVideo: true,
            ),
          ),
          'joinRoom',
        );

        // VolcEngine reports join completion through the room event handler.
        await completer.future;
      })().timeout(
        joinTimeout,
        onTimeout: () => throw const XmaxError(
          code: XmaxErrorCode.timeout,
          message: 'RTC join room timed out',
        ),
      );
    } catch (_) {
      try {
        await leaveRoom();
      } catch (_) {}
      rethrow;
    }
  }

  @override
  Future<void> leaveRoom() async {
    final room = _room;

    // Clear state before awaiting the SDK to make leave idempotent/reentrant.
    _room = null;
    _roomID = '';
    _remoteStreamIDs.clear();

    if (room == null) {
      return;
    }

    Object? cleanupError;
    try {
      await room.leaveRoom().timeout(cleanupTimeout);
    } catch (error) {
      cleanupError = error;
    }

    try {
      await room.destroy().timeout(cleanupTimeout);
    } catch (error) {
      cleanupError ??= error;
    }

    if (cleanupError != null) {
      throw XmaxError.from(cleanupError);
    }
  }

  @override
  Future<void> publishLocalVideo({required bool publish}) async {
    await _check(
      _requiredRoom.publishStreamVideo(publish),
      'publishStreamVideo',
    );
  }

  @override
  Future<void> subscribeRemoteVideo({
    required String streamID,
    required bool subscribe,
  }) async {
    await _check(
      _requiredRoom.subscribeStreamVideo(
        streamId: streamID,
        subscribe: subscribe,
      ),
      'subscribeStreamVideo',
    );
  }

  @override
  Future<void> subscribeRemoteAudio({
    required String streamID,
    required bool subscribe,
  }) async {
    await _check(
      _requiredRoom.subscribeStreamAudio(
        streamId: streamID,
        subscribe: subscribe,
      ),
      'subscribeStreamAudio',
    );
  }

  @override
  Future<void> setRemoteAudioVolume({
    required int volume,
    required String streamID,
  }) async {
    if (volume < 0 || volume > 100) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'RTC audio volume must be between 0 and 100',
      );
    }
    await _check(
      _engine.setRemoteAudioPlaybackVolume(streamId: streamID, volume: volume),
      'setRemoteAudioPlaybackVolume',
    );
  }

  @override
  Future<void> sendRoomMessage(String message) async {
    final room = _requiredRoom;

    if (Platform.isAndroid) {
      // volc_engine_rtc 3.60.6 declares this result as int, while its Android
      // bridge serializes the native long message ID as a String. Calling the
      // generated wrapper therefore sends the message and then throws a cast
      // error. Invoke the same native method directly until the plugin fixes
      // its generated return type.
      final dynamic platformRoom = room.$instance;
      final Object? result = await platformRoom.nativeCall<Object?>(
        'sendRoomMessage',
        <Object?>[message],
      );
      final status = int.tryParse(result?.toString() ?? '');

      if (status != null && status < 0) {
        throw XmaxError(
          code: XmaxErrorCode.rtcError,
          message: 'RTC sendRoomMessage failed: $status',
        );
      }
      return;
    }

    await _check(room.sendRoomMessage(message), 'sendRoomMessage');
  }

  @override
  void setEventListener(RtcEventListener? listener) {
    _eventListener = listener;
  }

  @override
  void setCameraPreviewReadyListener(void Function()? listener) {
    _cameraPreviewReadyListener = listener;
  }

  RTCRoom get _requiredRoom {
    final room = _room;
    if (room == null) {
      throw const XmaxError(
        code: XmaxErrorCode.rtcError,
        message: 'RTC room is not joined',
      );
    }
    return room;
  }

  IRTCEngineEventHandler _makeEngineEventHandler() => IRTCEngineEventHandler(
    onError: (code) {
      _eventListener?.onError?.call(
        XmaxError(
          code: XmaxErrorCode.rtcError,
          message: 'RTC Engine error: ${code.name}',
        ),
      );
    },
    onFirstLocalVideoFrameCaptured: (_, _) {
      _cameraPreviewReadyListener?.call();
    },
    onFirstRemoteVideoFrameDecoded: (streamID, info, _) {
      _eventListener?.onFirstRemoteVideoFrameDecoded?.call(
        _remoteStream(streamID, info),
      );
    },
    onSEIMessageReceived: (streamID, info, Uint8List message) {
      _eventListener?.onSEIMessageReceived?.call(
        _remoteStream(streamID, info),
        message,
      );
    },
    onPerformanceAlarms: (_, _, _, reason, data) {
      final reasonName = reason.name.toLowerCase();

      // Only fallback/resume alarms represent a quality state transition.
      final bool? limited = reasonName.contains('resumed')
          ? false
          : reasonName.contains('fallback')
          ? true
          : null;
      if (limited == null) {
        return;
      }

      final validSuggestion =
          data.width > 0 && data.height > 0 && data.frameRate > 0;
      _eventListener?.onPerformanceAlarm?.call(
        RealtimePerformanceAlarm(
          status: limited
              ? RealtimePerformanceStatus.limited
              : RealtimePerformanceStatus.recovered,
          suggestedVideoFormat: validSuggestion
              ? RealtimeVideoFormat(
                  width: data.width,
                  height: data.height,
                  fps: data.frameRate,
                )
              : null,
        ),
      );
    },
  );

  IRTCRoomEventHandler _makeRoomEventHandler({
    required RTCRoom room,
    required Completer<void> joinCompleter,
  }) => IRTCRoomEventHandler(
    // VolcEngine 3.60 uses this callback on current Android releases. Keep the
    // deprecated callback below as a fallback for iOS and older native SDKs.
    onRoomStateChangedWithReason: (roomID, _, state, reason) {
      _completeRoomJoin(
        room: room,
        joinCompleter: joinCompleter,
        roomID: roomID,
        // The plugin exposes this callback but does not re-export RoomState.
        joined: state.name == 'success',
        failureReason: reason.name,
      );
    },
    onRoomStateChanged: (roomID, _, state, extraInfo) {
      _completeRoomJoin(
        room: room,
        joinCompleter: joinCompleter,
        roomID: roomID,
        joined: state == 0,
        failureReason: extraInfo.trim().isEmpty ? '$state' : extraInfo,
      );
    },
    onUserPublishStreamVideo: (streamID, info, published) {
      _remoteStreamIDs[info.userId] = streamID;
      _eventListener?.onRemoteVideoPublished?.call(
        _remoteStream(streamID, info),
        published,
      );
    },
    onNetworkQuality: (local, remote) {
      // Report the worst remote downlink when the SDK supplies multiple users.
      var downlink = RealtimeNetworkQualityLevel.unknown;
      for (final item in remote) {
        final level = _qualityLevel(item.rxQuality);
        if (level.index > downlink.index) {
          downlink = level;
        }
      }

      _eventListener?.onNetworkQuality?.call(
        RealtimeNetworkQuality(
          uplink: _qualityLevel(local.txQuality),
          downlink: downlink,
        ),
      );
    },
  );

  void _completeRoomJoin({
    required RTCRoom room,
    required Completer<void> joinCompleter,
    required String roomID,
    required bool joined,
    required String failureReason,
  }) {
    if (!identical(_room, room) ||
        roomID != _roomID ||
        joinCompleter.isCompleted) {
      return;
    }

    if (joined) {
      joinCompleter.complete();
      return;
    }

    joinCompleter.completeError(
      XmaxError(
        code: XmaxErrorCode.rtcError,
        message: 'RTC join room failed: $failureReason',
      ),
    );
  }

  RemoteStream _remoteStream(String streamID, StreamInfo info) => RemoteStream(
    roomID: info.roomId,
    userID: info.userId,
    streamID: streamID,
  );

  static RealtimeNetworkQualityLevel _qualityLevel(NetworkQuality quality) {
    final name = quality.name.toLowerCase();

    if (name.contains('very_bad') || name.contains('verybad')) {
      return RealtimeNetworkQualityLevel.veryBad;
    }

    if (name.contains('excellent')) {
      return RealtimeNetworkQualityLevel.excellent;
    }

    if (name.contains('good')) {
      return RealtimeNetworkQualityLevel.good;
    }

    if (name.contains('poor')) {
      return RealtimeNetworkQualityLevel.poor;
    }

    if (name.contains('bad')) {
      return RealtimeNetworkQualityLevel.bad;
    }

    if (name.contains('down')) {
      return RealtimeNetworkQualityLevel.down;
    }
    return RealtimeNetworkQualityLevel.unknown;
  }

  static Future<void> _check(Future<int?> result, String operation) async {
    try {
      final status = await result;

      if (status != null && status < 0) {
        throw XmaxError(
          code: XmaxErrorCode.rtcError,
          message: 'RTC $operation failed: $status',
        );
      }
    } on XmaxError {
      rethrow;
    } catch (error) {
      throw XmaxError(
        code: XmaxErrorCode.rtcError,
        message: 'RTC $operation failed: $error',
      );
    }
  }

  static void _validateVideoDimensions(int width, int height, int fps) {
    if (width <= 0 || height <= 0 || fps <= 0 || width.isOdd || height.isOdd) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message:
            'RTC video width and height must be positive even numbers, '
            'and frame rate must be greater than zero',
      );
    }
  }

  static void _validateJoinConfiguration(RoomJoinConfiguration configuration) {
    if (configuration.roomID.trim().isEmpty ||
        configuration.userID.trim().isEmpty ||
        configuration.token.trim().isEmpty) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'RTC room ID, user ID, and token cannot be empty',
      );
    }
  }
}
