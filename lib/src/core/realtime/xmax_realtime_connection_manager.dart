import '../../foundation/errors/xmax_error.dart';
import '../../media/interaction/interaction_controlling.dart';
import '../../render/render_controlling.dart';
import '../../service/realtime/realtime_media_stream.dart';
import '../../service/realtime/realtime_session.dart';
import '../../service/realtime/realtime_session_servicing.dart';
import '../../service/realtime/realtime_video_format.dart';
import '../../service/realtime/realtime_video_track.dart';
import '../../stream/stream_controlling.dart';
import 'realtime_model.dart';

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
      if (isCurrent()) {
        await _rollbackConnection();
      }
      if (session != null && !activated) {
        try {
          await _sessionService.closeSession(sessionID: session.id);
        } catch (_) {}
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
    _activeSession = null;
    _activeRemoteTrack = null;
    _sessionService.stopHeartbeat();
    _renderController.resetRemoteTrack(track);
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
    _renderController.resetRemoteTrack(track);
    await _streamController.disconnect();
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
