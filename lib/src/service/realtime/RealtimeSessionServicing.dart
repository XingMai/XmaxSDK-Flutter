import '../../core/realtime/RealtimeModel.dart';
import 'RealtimeSession.dart';

abstract interface class RealtimeSessionServicing {
  Future<RealtimeSession> createSession({required RealtimeModel model});

  void startHeartbeat({
    required String sessionID,
    required RealtimeSessionHeartbeatFailureHandler onFailure,
  });

  void stopHeartbeat();

  Future<void> closeSession({required String sessionID});
}
