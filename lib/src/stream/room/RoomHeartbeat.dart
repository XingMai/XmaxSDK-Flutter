import 'dart:async';

import '../../foundation/rtc/RtcManaging.dart';
import 'RoomEvent.dart';

final class RoomHeartbeat {
  RoomHeartbeat({
    required RtcManaging rtcManager,
    this.interval = const Duration(seconds: 10),
  }) : _rtcManager = rtcManager;

  final RtcManaging _rtcManager;
  final Duration interval;
  Timer? _timer;
  int _version = 0;

  void start({required String userID}) {
    stop();
    final version = ++_version;
    _timer = Timer.periodic(interval, (_) {
      if (version == _version) {
        unawaited(
          _rtcManager.sendRoomMessage(RoomEvent.heartbeat(userID: userID)),
        );
      }
    });
  }

  void stop() {
    _version += 1;
    _timer?.cancel();
    _timer = null;
  }
}
