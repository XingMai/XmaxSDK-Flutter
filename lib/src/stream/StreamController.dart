import 'dart:async';
import 'dart:convert';
import 'dart:ui';

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
typedef RemoteFrameRenderedListener = void Function(RemoteStream stream);

final class StreamController implements StreamControlling {
  StreamController({
    required RtcManaging rtcManager,
    RoomControlling? roomController,
    EncodingControlling? encodingController,
    QualityControlling? qualityController,
    RealtimeErrorListener? errorListener,
    RealtimeErrorListener? localMediaErrorListener,
    RemoteStreamListener? remoteStreamListener,
    RemoteFrameRenderedListener? remoteFrameRenderedListener,
    RemoteFrameRenderedListener? remoteFrameReadyListener,
    this.generationTimeout = const Duration(seconds: 15),
  }) : _rtcManager = rtcManager,
       _roomController =
           roomController ?? RoomController(rtcManager: rtcManager),
       _encodingController =
           encodingController ?? EncodingController(rtcManager: rtcManager),
       _qualityController = qualityController ?? QualityController(),
       _errorListener = errorListener,
       _localMediaErrorListener = localMediaErrorListener,
       _remoteStreamListener = remoteStreamListener,
       _remoteFrameReadyListener = remoteFrameReadyListener,
       _remoteFrameRenderedListener = remoteFrameRenderedListener {
    rtcManager.setEventListener(
      RtcEventListener(
        onRemoteVideoPublished: _onRemoteVideoPublished,
        onFirstRemoteVideoFrameRendered: _onFirstRemoteVideoFrameRendered,
        onFirstRemoteVideoFrameDecoded: _onFirstRemoteVideoFrameDecoded,
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
  final RealtimeErrorListener? _localMediaErrorListener;
  final RemoteStreamListener? _remoteStreamListener;
  final RemoteFrameRenderedListener? _remoteFrameRenderedListener;
  final RemoteFrameRenderedListener? _remoteFrameReadyListener;
  final Duration generationTimeout;

  String _roomID = '';
  int _connectionRevision = 0;
  String _botName = '';
  bool _localVideoPublished = false;
  final Set<String> _remoteVideoSubscriptions = <String>{};
  final Set<(String, String, String)> _renderedRemoteStreams = {};
  final Set<(String, String, String)> _decodedRemoteStreams = {};
  final Map<String, String> _publishedRemoteAudioStreams = <String, String>{};
  RemoteStream? _activeRemoteStream;
  String? _subscribedRemoteAudioStreamID;
  Future<void>? _audioActivation;
  bool _remoteAudioEnabled = false;
  int _remoteAudioVolumePercentage = 100;
  int _audioSubscriptionVersion = 0;
  String? _generationTaskID;
  Completer<void>? _generationCompleter;
  Timer? _generationTimer;
  int _receivedGenerationSeiCount = 0;
  int _expectedRemoteSeiCount = 0;

  @override
  bool get hasGenerationTask => _generationTaskID != null;

  @override
  double get remoteAudioVolume => _remoteAudioVolumePercentage / 100;

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

    _remoteAudioEnabled = true;
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
    _connectionRevision += 1;
    _renderedRemoteStreams.clear();
    _decodedRemoteStreams.clear();
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
      _renderedRemoteStreams.clear();
      _decodedRemoteStreams.clear();
      rethrow;
    }
  }

  @override
  Future<void> disconnect() async {
    _connectionRevision += 1;
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
    _renderedRemoteStreams.clear();
    _decodedRemoteStreams.clear();
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
    Size? targetSize,
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
    _receivedGenerationSeiCount = 0;
    _expectedRemoteSeiCount = 0;
    _generationTimer = Timer(generationTimeout, () {
      // Keep the handshake evidence even when XLab later displays an RTC
      // quality warning. Never include the prompt, credentials or SEI payload.
      XmaxLogger.warn(
        category: XmaxLoggerCategory.stream,
        message:
            '生成确认超时 (Generation Confirmation Timed Out)\n'
            '├─ ${XmaxLogger.localized('taskID：', 'taskID: ')}$taskID\n'
            '├─ ${XmaxLogger.localized('视频订阅数：', 'Video Subscriptions: ')}${_remoteVideoSubscriptions.length}\n'
            '├─ ${XmaxLogger.localized('收到 SEI：', 'Received SEI: ')}$_receivedGenerationSeiCount\n'
            '└─ ${XmaxLogger.localized('来自目标远端的 SEI：', 'SEI from Expected Remote: ')}$_expectedRemoteSeiCount',
      );
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
        targetSize: targetSize,
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
    Size? targetSize,
  }) => _roomController.changeGenerationCondition(
    taskID: taskID,
    videoFormat: videoFormat,
    context: context,
    targetSize: targetSize,
  );

  @override
  Future<void> changeTargetSize({
    required String taskID,
    required Size targetSize,
    required void Function() ensureActive,
  }) => _roomController.changeTargetSize(
    taskID: taskID,
    targetSize: targetSize,
    ensureActive: ensureActive,
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
      _decodedRemoteStreams.remove((
        stream.roomID,
        stream.userID,
        stream.streamID,
      ));
      _renderedRemoteStreams.remove((
        stream.roomID,
        stream.userID,
        stream.streamID,
      ));
      if (_activeRemoteStream?.streamID == stream.streamID) {
        _activeRemoteStream = null;
        unawaited(_deactivateRemoteAudio());
        _clearRemoteStream();
      }
    }
  }

  void _onFirstRemoteVideoFrameDecoded(RemoteStream stream) {
    if (!_isExpectedRemote(stream)) return;
    _decodedRemoteStreams.add((stream.roomID, stream.userID, stream.streamID));
    final active = _activeRemoteStream;
    if (active != null &&
        active.roomID == stream.roomID &&
        active.userID == stream.userID &&
        active.streamID == stream.streamID) {
      _remoteFrameReadyListener?.call(stream);
    }
  }

  void _onFirstRemoteVideoFrameRendered(RemoteStream stream) {
    if (!_isExpectedRemote(stream)) return;

    // RTC reports the first frame per subscription, not per generation task.
    // It may arrive before the SEI selects a stream, so retain this evidence
    // until unpublish/disconnect and replay it only after a matching task SEI.
    _renderedRemoteStreams.add((stream.roomID, stream.userID, stream.streamID));
    final active = _activeRemoteStream;
    if (active == null ||
        active.roomID != stream.roomID ||
        active.userID != stream.userID ||
        active.streamID != stream.streamID) {
      return;
    }

    _remoteFrameRenderedListener?.call(stream);
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
    if (!_remoteAudioEnabled) return;
    final revision = _audioSubscriptionVersion;
    final connectionRevision = _connectionRevision;
    try {
      await activateRemoteAudio();
    } catch (error) {
      if (revision != _audioSubscriptionVersion ||
          connectionRevision != _connectionRevision) {
        return;
      }
      final xmaxError = XmaxError.from(error);
      if (xmaxError.code != XmaxErrorCode.cancelled) {
        _errorListener?.call(xmaxError);
      }
    }
  }

  Future<void> _subscribeRemoteVideo(RemoteStream stream) async {
    final revision = _connectionRevision;
    try {
      await _rtcManager.subscribeRemoteVideo(
        streamID: stream.streamID,
        subscribe: true,
      );
    } catch (error) {
      // A late subscription failure from the previous room must not remove a
      // new subscription with the same ID or reject its generation handshake.
      if (revision != _connectionRevision) return;
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

    _receivedGenerationSeiCount += 1;
    final expectedRemote = _isExpectedRemote(stream);
    if (expectedRemote) _expectedRemoteSeiCount += 1;

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
    // os/index query parameters describe a frame, not its task.
    // Compare the complete base ID, while retaining the room/bot identity check.
    final receivedID = message.split('?').first;
    final currentID = taskID.split('?').first;
    final matchesTask = receivedID.isNotEmpty && receivedID == currentID;
    if (!matchesTask || !expectedRemote) {
      if (_receivedGenerationSeiCount == 1) {
        XmaxLogger.debug(
          category: XmaxLoggerCategory.stream,
          message:
              '忽略不匹配的生成 SEI (Ignored Generation SEI)\n'
              '├─ ${XmaxLogger.localized('task 匹配：', 'Task Match: ')}$matchesTask\n'
              '└─ ${XmaxLogger.localized('room/bot 匹配：', 'Room/Bot Match: ')}$expectedRemote',
        );
      }
      return;
    }

    XmaxLogger.debug(
      category: XmaxLoggerCategory.stream,
      message:
          '生成 SEI 确认成功 (Generation SEI Confirmed)\n└─ ${XmaxLogger.localized('taskID：', 'taskID: ')}$taskID',
    );
    _activeRemoteStream = stream;
    _remoteStreamListener?.call(stream);
    if (_decodedRemoteStreams.contains((
      stream.roomID,
      stream.userID,
      stream.streamID,
    ))) {
      _remoteFrameReadyListener?.call(stream);
    }
    if (_renderedRemoteStreams.contains((
      stream.roomID,
      stream.userID,
      stream.streamID,
    ))) {
      _remoteFrameRenderedListener?.call(stream);
    }
    _generationTimer?.cancel();
    _generationTimer = null;
    _generationCompleter = null;
    completer.complete();
  }

  void _onError(Object error) {
    final xmaxError = XmaxError.from(error);
    if (!_rejectGeneration(xmaxError)) {
      final listener = _roomID.isEmpty
          ? (_localMediaErrorListener ?? _errorListener)
          : _errorListener;
      listener?.call(xmaxError);
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
    _remoteAudioEnabled = false;
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
            '└─ ${XmaxLogger.localized('原因：', 'Reason: ')}$error',
      );
    }
  }

  Future<void> _safe(String title, Future<void> Function() operation) async {
    try {
      await operation();
    } catch (error) {
      XmaxLogger.error(
        category: XmaxLoggerCategory.stream,
        message: '$title\n└─ ${XmaxLogger.localized('原因：', 'Reason: ')}$error',
      );
    }
  }
}
