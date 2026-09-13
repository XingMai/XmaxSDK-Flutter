import '../../foundation/errors/XmaxError.dart';

/// 实时视频的编码策略偏好。
enum RealtimeVideoEncoderPreference {
  /// 平衡帧率和分辨率。
  auto,

  /// 优先保障帧率。
  maintainFramerate,

  /// 优先保障分辨率。
  maintainQuality,
}

/// 实时视频的尺寸、帧率和上传编码配置。
final class RealtimeVideoFormat {
  const RealtimeVideoFormat({
    required this.width,
    required this.height,
    required this.fps,
    this.minimumBitrate,
    this.maximumBitrate,
    this.encoderPreference = RealtimeVideoEncoderPreference.auto,
  });

  /// 视频宽度，单位为像素。
  final int width;

  /// 视频高度，单位为像素。
  final int height;

  /// 视频帧率。
  final int fps;

  /// 最低上传码率，单位为 kbps；`null` 使用 SDK 默认值，0 表示不设最低码率。
  final int? minimumBitrate;

  /// 最高上传码率，单位为 kbps；`null` 使用 SDK 默认值，指定时必须大于 0。
  final int? maximumBitrate;

  /// 上传编码策略偏好，默认平衡帧率和分辨率。
  final RealtimeVideoEncoderPreference encoderPreference;

  /// 校验尺寸、帧率和显式指定的码率范围。
  void validate() {
    if (width <= 0 || height <= 0 || fps <= 0 || width.isOdd || height.isOdd) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message:
            'Realtime video width and height must be positive even '
            'numbers, and fps must be greater than zero',
      );
    }
    final minimum = minimumBitrate;
    final maximum = maximumBitrate;
    if (minimum != null && minimum < 0) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'Minimum bitrate must not be negative',
      );
    }
    if (maximum != null && maximum <= 0) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'Maximum bitrate must be greater than zero',
      );
    }
    if (minimum != null && maximum != null && minimum > maximum) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'Minimum bitrate must not exceed maximum bitrate',
      );
    }
  }

  /// 调整尺寸，保留帧率和上传编码配置。
  RealtimeVideoFormat resized({required int width, required int height}) =>
      RealtimeVideoFormat(
        width: width,
        height: height,
        fps: fps,
        minimumBitrate: minimumBitrate,
        maximumBitrate: maximumBitrate,
        encoderPreference: encoderPreference,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RealtimeVideoFormat &&
          width == other.width &&
          height == other.height &&
          fps == other.fps &&
          minimumBitrate == other.minimumBitrate &&
          maximumBitrate == other.maximumBitrate &&
          encoderPreference == other.encoderPreference;

  @override
  int get hashCode => Object.hash(
    width,
    height,
    fps,
    minimumBitrate,
    maximumBitrate,
    encoderPreference,
  );
}
