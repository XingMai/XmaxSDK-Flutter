enum RealtimeConnectionState {
  idle('Idle'),
  connecting('Connecting'),
  connected('Connected'),
  generating('Generating'),
  disconnecting('Disconnecting'),
  disconnected('Disconnected'),
  error('Error');

  const RealtimeConnectionState(this.value);

  final String value;
}

final class RealtimeState {
  const RealtimeState({
    required this.connectionState,
    this.sessionID,
    this.taskID,
  });

  final RealtimeConnectionState connectionState;
  final String? sessionID;
  final String? taskID;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RealtimeState &&
          connectionState == other.connectionState &&
          sessionID == other.sessionID &&
          taskID == other.taskID;

  @override
  int get hashCode => Object.hash(connectionState, sessionID, taskID);
}

typedef RealtimeStateListener = void Function(RealtimeState state);
