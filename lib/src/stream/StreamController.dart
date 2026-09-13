import 'dart:async';
import 'dart:convert';

import '../foundation/errors/XmaxError.dart';
import '../foundation/logging/XmaxLogger.dart';
import '../foundation/rtc/RtcEventListener.dart';
import '../foundation/rtc/RtcManaging.dart';
import '../foundation/rtc/RtcModels.dart';
import '../service/realtime/RealtimeContext.dart';
import '../service/realtime/RealtimeError.dart';
import '../service/realtime/RealtimeNetworkQuality.dart';
import '../service/realtime/RealtimePerformanceAlarm.dart';
import '../service/realtime/RealtimePoint.dart';
import '../service/realtime/RealtimeSession.dart';
import '../service/realtime/RealtimeVideoFormat.dart';
import 'encoding/EncodingController.dart';
import 'encoding/EncodingControlling.dart';
import 'quality/QualityController.dart';
import 'quality/QualityControlling.dart';
import 'room/RoomController.dart';
import 'room/RoomControlling.dart';
import 'StreamControlling.dart';

typedef RemoteStreamListener = void Function(RemoteStream? stream);

final class StreamController implements StreamControlling {
  StreamController({
    required RtcManaging rtcManager,
    RoomControlling? roomController,
    EncodingControlling? encodingController,
    QualityControlling? qualityController,
    RealtimeErrorListener? errorListener,
    RemoteStreamListener? remoteStreamListener,
    this.generationTimeout = const Duration(seconds: 15),
  }) : _rtcManager = rtcManager,
       _roomController =
           roomController ?? RoomController(rtcManager: rtcManager),
       _encodingController =
           encodingController ?? EncodingController(rtcManager: rtcManager),
       _qualityController = qualityController ?? QualityController(),
       _errorListener = errorListener,
       _remoteStreamListener = remoteStreamListener {
    rtcManager.setEventListener(
      RtcEventListener(
        onRemoteVideoPublished: _onRemoteVideoPublished,
        onRemoteAudioPublished: _onRemoteAudioPublished,
        onSEIMessageReceived: _onSEIMessageReceived,
        onError: _onError,
        onNetworkQuality: _qualityController.emitNetworkQuality,
        onPerformanceAlarm: _qualityController.emitPerformanceAlarm,
      ),
    );
  }

  final RtcManaging _rtcManager;
  final RoomControlling _roomController;
  final EncodingControlling _encodingController;
  final QualityControlling _qualityController;
  final RealtimeErrorListener? _errorListener;
  final RemoteStreamListener? _remoteStreamListener;
  final Duration generationTimeout;

  String _roomID = '';
  String _botName = '';
  bool _localVideoPublished = false;
  final Set<String> _remoteVideoSubscriptions = <String>{};
  final Map<String, String> _publishedRemoteAudioStreams = <String, String>{};
  RemoteStream? _activeRemoteStream;
  String? _subscribedRemoteAudioStreamID;
  Future<void>? _audioActivation;
  int _remoteAudioVolumePercentage = 0;
  int _audioSubscriptionVersion = 0;
  String? _generationTaskID;
  Completer<void>? _generationCompleter;
  Timer? _generationTimer;

  @override
  bool get hasGenerationTask => _generationTaskID != null;

  @override
  Future<void> setVideoEncoderConfig(RealtimeVideoFormat videoFormat) =>
      _encodingController.configure(videoFormat);

  @override
  void setNetworkQualityListener(RealtimeNetworkQualityListener? listener) {
    _qualityController.setNetworkQualityListener(listener);
  }

  @override
  void setPerformanceAlarmListener(RealtimePerformanceAlarmListener? listener) {
    _qualityController.setPerformanceAlarmListener(listener);
  }

  @override
  Future<void> setRemoteAudioVolume(double volume) async {
    if (!volume.isFinite || volume < 0 || volume > 1) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'Audio volume must be between 0 and 1',
      );
    }

    final rtcVolume = (volume * 100).round();
    final streamID = _subscribedRemoteAudioStreamID;
    if (streamID != null) {
      await _rtcManager.setRemoteAudioVolume(
        volume: rtcVolume,
        streamID: streamID,
      );
    }
    _remoteAudioVolumePercentage = rtcVolume;
  }

  @override
  Future<void> activateRemoteAudio() async {
    final stream = _activeRemoteStream;
    if (_generationTaskID == null || stream == null) {
      throw const XmaxError(
        code: XmaxErrorCode.rtcError,
        message: 'Remote generation audio stream is unavailable',
      );
    }

    // The RTC audio stream can use an ID different from the SEI video stream.
    // If its publish event has not arrived, subscribe when that event arrives.
    final streamID = _publishedRemoteAudioStreams[stream.userID];
    if (streamID == null) return;
    if (_subscribedRemoteAudioStreamID == streamID) return;

    final activeOperation = _audioActivation;
    if (activeOperation != null) return activeOperation;

    final operation = _performActivateRemoteAudio(stream, streamID);
    _audioActivation = operation;
    try {
      await operation;
    } finally {
      if (identical(_audioActivation, operation)) {
        _audioActivation = null;
      }
    }
  }

  Future<void> _performActivateRemoteAudio(
    RemoteStream stream,
    String streamID,
  ) async {
    final version = _audioSubscriptionVersion;
    final initialVolume = _remoteAudioVolumePercentage;
    await _rtcManager.setRemoteAudioVolume(
      volume: initialVolume,
      streamID: streamID,
    );
    _ensureAudioStreamCurrent(stream, streamID, version);

    await _rtcManager.subscribeRemoteAudio(streamID: streamID, subscribe: true);
    if (!_isAudioStreamCurrent(stream, streamID, version)) {
      await _safe(
        '取消过期 RTC 远端音频订阅失败 '
        '(Failed to Unsubscribe from Stale RTC Remote Audio)',
        () => _rtcManager.subscribeRemoteAudio(
          streamID: streamID,
          subscribe: false,
        ),
      );
      _ensureAudioStreamCurrent(stream, streamID, version);
    }

    _subscribedRemoteAudioStreamID = streamID;
    if (initialVolume != _remoteAudioVolumePercentage) {
      await _rtcManager.setRemoteAudioVolume(
        volume: _remoteAudioVolumePercentage,
        streamID: streamID,
      );
    }
  }

  @override
  Future<void> connect({
    required RealtimeSessionConnection connection,
    required void Function() ensureActive,
  }) async {
    // Existing remote streams may be reported while join() is still pending.
    _roomID = connection.roomID.trim();
    _botName = connection.botName?.trim() ?? '';
    try {
      await _roomController.join(
        connection: connection,
        ensureActive: ensureActive,
      );

      ensureActive();
      await _rtcManager.publishLocalVideo(publish: true);
      _localVideoPublished = true;
    } catch (_) {
      _roomID = '';
      _botName = '';
      _publishedRemoteAudioStreams.clear();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    // Stop the generation handshake before changing RTC subscriptions.
    await _clearGeneration(notifyRemote: true);

    for (final streamID in _remoteVideoSubscriptions.toList()) {
      await _safe(
        '取消订阅 RTC 远端视频失败 (Failed to Unsubscribe from RTC Remote Video)',
        () => _rtcManager.subscribeRemoteVideo(
          streamID: streamID,
          subscribe: false,
        ),
      );
    }

    if (_localVideoPublished) {
      await _safe(
        '取消发布 RTC 本地视频失败 (Failed to Unpublish RTC Local Video)',
        () => _rtcManager.publishLocalVideo(publish: false),
      );
    }

    _remoteVideoSubscriptions.clear();
    _publishedRemoteAudioStreams.clear();
    _localVideoPublished = false;
    _roomID = '';
    _botName = '';

    await _roomController.leave();
  }

  @override
  Future<GenerationStartConfirmation> beginGeneration({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
  }) async {
    if (taskID.trim().isEmpty) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'Realtime generation task ID cannot be empty',
      );
    }

    if (_roomID.isEmpty) {
      throw const XmaxError(
        code: XmaxErrorCode.rtcError,
        message: 'RTC room is not configured',
      );
    }

    if (_generationTaskID != null) {
      throw const XmaxError(
        code: XmaxErrorCode.rtcError,
        message: 'Realtime generation is already active',
      );
    }

    // Generation is acknowledged by an SEI message carrying this task ID.
    final completer = Completer<void>();
    // A cancellation may arrive immediately after the start signal is sent.
    // Attach a handler before exposing the confirmation to its caller.
    completer.future.ignore();
    _generationTaskID = taskID;
    _generationCompleter = completer;
    _generationTimer = Timer(generationTimeout, () {
      _rejectGeneration(
        const XmaxError(
          code: XmaxErrorCode.timeout,
          message: 'Realtime generation start timed out',
        ),
      );
    });

    try {
      await _roomController.startGeneration(
        taskID: taskID,
        videoFormat: videoFormat,
        context: context,
      );
      return GenerationStartConfirmation(
        value: completer.future,
        onCancel: () {
          if (_generationTaskID == taskID &&
              identical(_generationCompleter, completer)) {
            _rejectGeneration(
              const XmaxError(
                code: XmaxErrorCode.cancelled,
                message: 'Realtime generation start cancelled',
              ),
            );
          }
        },
      );
    } catch (error) {
      // The current invocation already reports this failure to its caller.
      // Detach its completer first so cleanup does not emit a second,
      // unobserved cancellation error through the Dart zone.
      if (identical(_generationCompleter, completer)) {
        _generationTimer?.cancel();
        _generationTimer = null;
        _generationCompleter = null;
      }

      // Cancel any remote task that may already have received the request.
      await _clearGeneration(notifyRemote: true);
      rethrow;
    }
  }

  @override
  Future<void> updateGeneration({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
  }) => _roomController.changeGenerationCondition(
    taskID: taskID,
    videoFormat: videoFormat,
    context: context,
  );

  @override
  Future<void> stopGeneration({required String taskID}) async {
    final stoppedTaskID = _generationTaskID;
    if (stoppedTaskID == null ||
        (taskID.isNotEmpty && taskID != stoppedTaskID)) {
      return;
    }

    await _clearGeneration(notifyRemote: true);
    await _roomController.stopGeneration(taskID: stoppedTaskID);
  }

  @override
  Future<void> sendTracks({
    required String taskID,
    required List<RealtimePoint> points,
  }) => _roomController.sendTracks(taskID: taskID, points: points);

  void _onRemoteVideoPublished(RemoteStream stream, bool published) {
    if (!_isExpectedRemote(stream)) {
      return;
    }

    if (published) {
      if (_remoteVideoSubscriptions.add(stream.streamID)) {
        unawaited(_subscribeRemoteVideo(stream));
      }
    } else {
      _remoteVideoSubscriptions.remove(stream.streamID);
      if (_activeRemoteStream?.streamID == stream.streamID) {
        _activeRemoteStream = null;
        unawaited(_deactivateRemoteAudio());
        _clearRemoteStream();
      }
    }
  }

  void _onRemoteAudioPublished(RemoteStream stream, bool published) {
    if (!_isExpectedRemote(stream)) return;

    if (published) {
      _publishedRemoteAudioStreams[stream.userID] = stream.streamID;
      if (_activeRemoteStream?.userID == stream.userID) {
        unawaited(_activatePublishedAudio());
      }
      return;
    }

    if (_publishedRemoteAudioStreams[stream.userID] != stream.streamID) return;
    _publishedRemoteAudioStreams.remove(stream.userID);
    if (_activeRemoteStream?.userID == stream.userID) {
      unawaited(_deactivateRemoteAudio());
    }
  }

  Future<void> _activatePublishedAudio() async {
    try {
      await activateRemoteAudio();
    } catch (error) {
      final xmaxError = XmaxError.from(error);
      if (xmaxError.code != XmaxErrorCode.cancelled) {
        _errorListener?.call(xmaxError);
      }
    }
  }

  Future<void> _subscribeRemoteVideo(RemoteStream stream) async {
    try {
      await _rtcManager.subscribeRemoteVideo(
        streamID: stream.streamID,
        subscribe: true,
      );
    } catch (error) {
      _remoteVideoSubscriptions.remove(stream.streamID);
      final xmaxError = XmaxError.from(error);
      if (!_rejectGeneration(xmaxError)) {
        _errorListener?.call(xmaxError);
      }
    }
  }

  void _onSEIMessageReceived(RemoteStream stream, List<int> bytes) {
    final taskID = _generationTaskID;
    final completer = _generationCompleter;
    if (taskID == null || completer == null || completer.isCompleted) {
      return;
    }

    final String message;
    try {
      message = utf8.decode(bytes).trim();
    } on FormatException {
      XmaxLogger.warn(
        category: XmaxLoggerCategory.rtc,
        message:
            '收到无法解码的 RTC SEI 消息 '
            '(Failed to Decode Incoming RTC SEI Message)',
      );
      return;
    }
    if (message != taskID || !_isExpectedRemote(stream)) {
      return;
    }

    _activeRemoteStream = stream;
    _remoteStreamListener?.call(stream);
    _generationTimer?.cancel();
    _generationTimer = null;
    _generationCompleter = null;
    completer.complete();
  }

  void _onError(Object error) {
    final xmaxError = XmaxError.from(error);
    if (!_rejectGeneration(xmaxError)) {
      _errorListener?.call(xmaxError);
    }
  }

  bool _isExpectedRemote(RemoteStream stream) =>
      stream.roomID == _roomID &&
      (_botName.isEmpty || stream.userID == _botName);

  bool _rejectGeneration(XmaxError error) {
    final completer = _generationCompleter;
    _generationTimer?.cancel();
    _generationTimer = null;
    _generationCompleter = null;

    if (completer != null && !completer.isCompleted) {
      completer.completeError(error);
      return true;
    }
    return false;
  }

  Future<void> _clearGeneration({required bool notifyRemote}) async {
    _rejectGeneration(
      const XmaxError(
        code: XmaxErrorCode.cancelled,
        message: 'Realtime generation start cancelled',
      ),
    );

    _generationTaskID = null;
    _activeRemoteStream = null;
    await _deactivateRemoteAudio();

    if (notifyRemote) {
      _clearRemoteStream();
    }
  }

  bool _isAudioStreamCurrent(
    RemoteStream stream,
    String streamID,
    int version,
  ) =>
      version == _audioSubscriptionVersion &&
      _generationTaskID != null &&
      identical(_activeRemoteStream, stream) &&
      _publishedRemoteAudioStreams[stream.userID] == streamID;

  void _ensureAudioStreamCurrent(
    RemoteStream stream,
    String streamID,
    int version,
  ) {
    if (!_isAudioStreamCurrent(stream, streamID, version)) {
      throw const XmaxError(
        code: XmaxErrorCode.cancelled,
        message: 'Remote generation audio subscription was cancelled',
      );
    }
  }

  Future<void> _deactivateRemoteAudio() async {
    final subscribedID = _subscribedRemoteAudioStreamID;
    _audioSubscriptionVersion += 1;
    _subscribedRemoteAudioStreamID = null;
    if (subscribedID == null) return;

    await _safe(
      '取消订阅 RTC 远端音频失败 (Failed to Unsubscribe from RTC Remote Audio)',
      () => _rtcManager.subscribeRemoteAudio(
        streamID: subscribedID,
        subscribe: false,
      ),
    );
  }

  void _clearRemoteStream() {
    try {
      _remoteStreamListener?.call(null);
    } catch (error) {
      XmaxLogger.error(
        category: XmaxLoggerCategory.stream,
        message:
            '清理 RTC 远端生成流失败 '
            '(Failed to Clean Up RTC Remote Generation Stream)\n'
            '└─ 原因：$error',
      );
    }
  }

  Future<void> _safe(String title, Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      XmaxLogger.error(
        category: XmaxLoggerCategory.stream,
        message: '$title\n└─ 原因：$error',
      );
    }
  }
}
