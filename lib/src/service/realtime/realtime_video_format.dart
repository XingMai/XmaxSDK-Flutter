import '../../foundation/errors/xmax_error.dart';

/// 实时视频的宽、高和帧率规格。
final class RealtimeVideoFormat {
  const RealtimeVideoFormat({
    required this.width,
    required this.height,
    required this.fps,
  });

  final int width;
  final int height;
  final int fps;

  void validate() {
    if (width <= 0 || height <= 0 || fps <= 0 || width.isOdd || height.isOdd) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message:
            'Realtime video width and height must be positive even '
            'numbers, and fps must be greater than zero',
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RealtimeVideoFormat &&
          width == other.width &&
          height == other.height &&
          fps == other.fps;

  @override
  int get hashCode => Object.hash(width, height, fps);
}
