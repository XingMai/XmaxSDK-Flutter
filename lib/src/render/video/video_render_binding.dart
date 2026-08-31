import '../../foundation/rtc/rtc_models.dart';

sealed class VideoRenderBinding {
  const VideoRenderBinding();
}

final class LocalVideoRenderBinding extends VideoRenderBinding {
  const LocalVideoRenderBinding();
}

final class RemoteVideoRenderBinding extends VideoRenderBinding {
  const RemoteVideoRenderBinding(this.stream);

  final RemoteStream stream;
}
