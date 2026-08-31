import 'realtime_video_track.dart';

/// 实时生成输入或输出的媒体流。
final class RealtimeMediaStream {
  const RealtimeMediaStream._({required this.id, this.videoTrack});

  final String id;
  final RealtimeVideoTrack? videoTrack;
}

/// Package-internal construction hook. Not exported by `xmax_sdk.dart`.
RealtimeMediaStream createRealtimeMediaStream({
  required String id,
  RealtimeVideoTrack? videoTrack,
}) => RealtimeMediaStream._(id: id, videoTrack: videoTrack);
