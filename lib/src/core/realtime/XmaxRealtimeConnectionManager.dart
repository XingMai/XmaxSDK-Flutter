import '../../foundation/errors/XmaxError.dart';
import '../../foundation/logging/XmaxLogger.dart';
import '../../media/interaction/InteractionControlling.dart';
import '../../render/RenderControlling.dart';
import '../../service/realtime/RealtimeMediaStream.dart';
import '../../service/realtime/RealtimeSession.dart';
import '../../service/realtime/RealtimeSessionServicing.dart';
import '../../service/realtime/RealtimeVideoFormat.dart';
import '../../service/realtime/RealtimeVideoTrack.dart';
import '../../stream/StreamControlling.dart';
import 'RealtimeModel.dart';

typedef RealtimeConnectionHeartbeatFailureHandler =
    Future<void> Function(String sessionID, Object error);

final class XmaxRealtimeConnectionManager {
  XmaxRealtimeConnectionManager({
    required RealtimeSessionServicing sessionService,
    required InteractionControlling interactionController,
    required RenderControlling renderController,
    required StreamControlling streamController,
  }) : _sessionService = sessionService,
       _interactionController = interactionController,
       _renderController = renderController,
       _streamController = streamController;

  final RealtimeSessionServicing _sessionService;
  final InteractionControlling _interactionController;
  final RenderControlling _renderController;
  final StreamControlling _streamController;
  RealtimeVideoTrack? _activeRemoteTrack;
  RealtimeSession? _activeSession;

  String get currentSessionID => _activeSession?.id ?? '';

  RealtimeMediaStream? get currentRemoteStream {
    final track = _activeRemoteTrack;
    if (_activeSession == null || track == null) {
      return null;
    }
    return createRealtimeMediaStream(id: 'stream-remote', videoTrack: track);
  }

  Future<RealtimeMediaStream> connect({
    required RealtimeModel model,
    required RealtimeVideoFormat videoFormat,
    required bool Function() isCurrent,
    required RealtimeConnectionHeartbeatFailureHandler onHeartbeatFailure,
  }) async {
    RealtimeSession? session;
    var activated = false;

    try {
      // The cloud session must exist before RTC can join its assigned room.
      session = await _sessionService.createSession(model: model);
      _ensureCurrent(isCurrent);

      final connection = session.connection;
      if (connection == null) {
        throw const XmaxError(
          code: XmaxErrorCode.sessionError,
          message: 'Session does not contain complete RTC join information',
        );
      }

      await _streamController.connect(
        connection: connection,
        ensureActive: () => _ensureCurrent(isCurrent),
      );
      _ensureCurrent(isCurrent);

      // Heartbeat starts only after RTC is connected successfully.
      _sessionService.startHeartbeat(
        sessionID: session.id,
        onFailure: onHeartbeatFailure,
      );

      final track = createRealtimeVideoTrack(
        id: connection.botName ?? 'video-remote',
        videoFormat: videoFormat,
      );
      _renderController.registerRemoteTrack(
        track,
        interactionListener: _interactionController.submitInteraction,
      );

      _activeSession = session;
      _activeRemoteTrack = track;
      activated = true;

      _ensureCurrent(isCurrent);
      return createRealtimeMediaStream(id: 'stream-remote', videoTrack: track);
    } catch (error) {
      // Roll back locally activated RTC/render state before closing the API session.
      if (isCurrent() || activated) {
        await _rollbackConnection();
      }

      if (session != null) {
        await _closeSessionAfterFailedConnection(session.id);
      }

      if (!isCurrent()) {
        throw const XmaxError(
          code: XmaxErrorCode.cancelled,
          message: 'Realtime connection was cancelled',
        );
      }
      throw XmaxError.from(error);
    }
  }

  Future<String?> disconnect() async {
    final session = _activeSession;
    final track = _activeRemoteTrack;

    // Clear ownership first so reentrant callbacks cannot reuse stale state.
    _activeSession = null;
    _activeRemoteTrack = null;

    _sessionService.stopHeartbeat();
    _resetRemoteRendering(track);
    await _streamController.disconnect();

    if (session != null) {
      await _sessionService.closeSession(sessionID: session.id);
    }

    return session?.id;
  }

  Future<void> _rollbackConnection() async {
    final track = _activeRemoteTrack;

    _activeSession = null;
    _activeRemoteTrack = null;

    _sessionService.stopHeartbeat();
    _resetRemoteRendering(track);
    await _streamController.disconnect();
  }

  void _resetRemoteRendering(RealtimeVideoTrack? track) {
    try {
      _renderController.resetRemoteTrack(track);
    } catch (error) {
      _logCleanupFailure(
        '重置远端视频渲染失败 (Failed to Reset Remote Video Rendering)',
        error,
      );
    }
  }

  Future<void> _closeSessionAfterFailedConnection(String sessionID) async {
    try {
      await _sessionService.closeSession(sessionID: sessionID);
    } catch (error) {
      _logCleanupFailure(
        '连接回滚关闭会话失败 '
        '(Failed to Close Session During Connection Rollback)',
        error,
      );
    }
  }

  static void _logCleanupFailure(String title, Object error) {
    XmaxLogger.error('$title\n└─ 原因：$error', category: 'Realtime');
  }

  static void _ensureCurrent(bool Function() isCurrent) {
    if (!isCurrent()) {
      throw const XmaxError(
        code: XmaxErrorCode.cancelled,
        message: 'Realtime connection was cancelled',
      );
    }
  }
}
