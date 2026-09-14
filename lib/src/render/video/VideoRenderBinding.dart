import '../../foundation/rtc/RtcModels.dart';

sealed class VideoRenderBinding {
  const VideoRenderBinding();
}

final class LocalVideoRenderBinding extends VideoRenderBinding {
  const LocalVideoRenderBinding({this.onPreviewAttached});

  /// Called after Flutter creates the native preview platform view.
  final void Function()? onPreviewAttached;
}

final class RemoteVideoRenderBinding extends VideoRenderBinding {
  const RemoteVideoRenderBinding(
    this.stream, {
    this.firstFrameRendered = false,
  });

  final RemoteStream stream;
  final bool firstFrameRendered;
}
