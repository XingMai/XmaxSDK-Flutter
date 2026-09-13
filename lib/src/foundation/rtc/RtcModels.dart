import '../../service/realtime/RealtimeVideoFormat.dart';

final class RoomJoinConfiguration {
  const RoomJoinConfiguration({
    required this.roomID,
    required this.userID,
    required this.token,
  });

  final String roomID;
  final String userID;
  final String token;
}

final class VideoEncodingConfiguration {
  const VideoEncodingConfiguration({
    required this.width,
    required this.height,
    required this.frameRate,
    this.minimumBitrate = 0,
    this.maximumBitrate = -1,
    this.encoderPreference = RealtimeVideoEncoderPreference.auto,
  });

  final int width;
  final int height;
  final int frameRate;
  final int minimumBitrate;
  final int maximumBitrate;
  final RealtimeVideoEncoderPreference encoderPreference;
}

final class RemoteStream {
  const RemoteStream({
    required this.roomID,
    required this.userID,
    required this.streamID,
  });

  final String roomID;
  final String userID;
  final String streamID;

  String get key => '$roomID:$userID';
}
