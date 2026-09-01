final class RealtimeSessionConnection {
  const RealtimeSessionConnection({
    required this.roomID,
    required this.userID,
    required this.token,
    this.botName,
  });

  final String roomID;
  final String userID;
  final String token;
  final String? botName;
}

final class RealtimeSession {
  const RealtimeSession({
    required this.id,
    this.userID,
    this.status,
    this.connection,
    this.closeReason,
  });

  final String id;
  final String? userID;
  final String? status;
  final RealtimeSessionConnection? connection;
  final String? closeReason;
}

typedef RealtimeSessionHeartbeatFailureHandler =
    Future<void> Function(String sessionID, Object error);
