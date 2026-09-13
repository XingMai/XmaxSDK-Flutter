import 'dart:math' as math;

import '../../foundation/errors/XmaxError.dart';
import '../../foundation/rtc/RtcManaging.dart';
import '../../foundation/rtc/RtcModels.dart';
import '../../service/realtime/RealtimeVideoFormat.dart';
import 'EncodingControlling.dart';

/// 根据实时视频格式配置 RTC 视频编码参数。
final class EncodingController implements EncodingControlling {
  const EncodingController({required RtcManaging rtcManager})
    : _rtcManager = rtcManager;

  final RtcManaging _rtcManager;

  @override
  Future<void> configure(RealtimeVideoFormat videoFormat) async {
    videoFormat.validate();

    final int minimum;
    final int maximum;
    final explicitMinimum = videoFormat.minimumBitrate;
    final explicitMaximum = videoFormat.maximumBitrate;
    if (explicitMinimum != null && explicitMaximum != null) {
      minimum = explicitMinimum;
      maximum = explicitMaximum;
    } else {
      final defaults = _defaultBitrates(videoFormat);
      minimum = explicitMinimum ?? defaults.$1;
      maximum = explicitMaximum ?? defaults.$2;
    }

    if (minimum > maximum) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message:
            'Minimum bitrate must not exceed maximum bitrate after applying '
            'SDK defaults',
      );
    }

    await _rtcManager.configureVideoEncoding(
      VideoEncodingConfiguration(
        width: videoFormat.width,
        height: videoFormat.height,
        frameRate: videoFormat.fps,
        minimumBitrate: minimum,
        maximumBitrate: maximum,
        encoderPreference: videoFormat.encoderPreference,
      ),
    );
  }

  static (int, int) _defaultBitrates(RealtimeVideoFormat format) {
    final bitrates = _resolveBitrates(
      pixels: format.width.toDouble() * format.height.toDouble(),
      fps: format.fps.toDouble(),
    );
    final roundedMinimum = bitrates.$1.roundToDouble();
    final roundedMaximum = bitrates.$2.roundToDouble();

    // Match iOS's Double(Int.max) guard before converting to an integer.
    if (!roundedMaximum.isFinite || roundedMaximum >= 9223372036854775808.0) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'Realtime video format exceeds the supported bitrate range',
      );
    }

    final minimum = math.max(1, roundedMinimum.toInt());
    final maximum = math.max(minimum + 1, roundedMaximum.toInt());
    return (minimum, maximum);
  }

  // 火山编码参考表：像素面积升序排列，码率单位 kbps。按 iOS EncodingController
  // 的相同曲线插值；表外尺寸按最近端点比例外推。
  static const _referenceBitratesAt15FPS = <_BitratePoint>[
    _BitratePoint(120 * 120, 50),
    _BitratePoint(160 * 120, 65),
    _BitratePoint(180 * 180, 100),
    _BitratePoint(240 * 180, 120),
    _BitratePoint(320 * 180, 140),
    _BitratePoint(320 * 240, 200),
    _BitratePoint(424 * 240, 220),
    _BitratePoint(360 * 360, 260),
    _BitratePoint(480 * 360, 320),
    _BitratePoint(640 * 360, 400),
    _BitratePoint(640 * 480, 500),
    _BitratePoint(848 * 480, 610),
    _BitratePoint(960 * 720, 910),
    _BitratePoint(1280 * 720, 1130),
    _BitratePoint(1920 * 1080, 2080),
  ];

  static const _referenceBitratesAt30FPS = <_BitratePoint>[
    _BitratePoint(360 * 360, 400),
    _BitratePoint(480 * 360, 490),
    _BitratePoint(640 * 360, 600),
    _BitratePoint(640 * 480, 750),
    _BitratePoint(848 * 480, 930),
    _BitratePoint(960 * 720, 1380),
    _BitratePoint(1280 * 720, 1710),
    _BitratePoint(1920 * 1080, 3150),
  ];

  static (double, double) _resolveBitrates({
    required double pixels,
    required double fps,
  }) {
    final bitrate15 = _interpolate(pixels, _referenceBitratesAt15FPS);
    final first30 = _referenceBitratesAt30FPS.first;
    final bitrate30 = pixels < first30.value
        ? bitrate15 *
              (first30.bitrate /
                  _interpolate(first30.value, _referenceBitratesAt15FPS))
        : _interpolate(pixels, _referenceBitratesAt30FPS);

    // 10fps 沿用 15fps 尺寸曲线；60fps 沿用 30fps 尺寸曲线。
    final bitrate10 = bitrate15 * (400.0 / 500);
    final minimum60 = bitrate30 * (4780.0 / 3150);
    final maximum60 = bitrate30 * (6500.0 / 3150);

    return (
      _interpolate(fps, <_BitratePoint>[
        _BitratePoint(10, bitrate10),
        _BitratePoint(15, bitrate15),
        _BitratePoint(30, bitrate30),
        _BitratePoint(60, minimum60),
      ]),
      _interpolate(fps, <_BitratePoint>[
        _BitratePoint(10, bitrate10 * 2),
        _BitratePoint(15, bitrate15 * 2),
        _BitratePoint(30, bitrate30 * 2),
        _BitratePoint(60, maximum60),
      ]),
    );
  }

  static double _interpolate(double value, List<_BitratePoint> points) {
    final first = points.first;
    if (value <= first.value) {
      return first.bitrate * (value / first.value);
    }

    for (var index = 1; index < points.length; index++) {
      final upper = points[index];
      if (value <= upper.value) {
        final lower = points[index - 1];
        final ratio = (value - lower.value) / (upper.value - lower.value);
        return lower.bitrate + (upper.bitrate - lower.bitrate) * ratio;
      }
    }

    final last = points.last;
    return last.bitrate * (value / last.value);
  }
}

final class _BitratePoint {
  const _BitratePoint(this.value, this.bitrate);

  final double value;
  final double bitrate;
}
