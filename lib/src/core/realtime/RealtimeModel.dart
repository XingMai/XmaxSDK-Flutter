import 'package:flutter/widgets.dart';

import '../../service/realtime/RealtimeVideoFormat.dart';

/// SDK 当前支持的实时生成模型。
enum RealtimeModel {
  /// Xmax X2.0 实时生成模型。
  x2_0('x2.0'),

  /// Xmax X2.0 Pro 实时生成模型。
  // Keep the public case name aligned with the iOS SDK.
  // ignore: constant_identifier_names
  x2_0_pro('x2.0-pro');

  const RealtimeModel(this.value);

  final String value;

  /// 模型支持的输入分辨率桶；非空时宽高必须精确匹配，不进行自动缩放。
  /// 空列表表示不限制固定尺寸，按像素面积上下限和对齐规则计算输入尺寸。
  List<Size> get resolutionBuckets => switch (this) {
    RealtimeModel.x2_0 => const <Size>[],
    RealtimeModel.x2_0_pro => const <Size>[Size(1024, 1920), Size(1920, 1024)],
  };

  /// 输入分辨率的最小总像素面积；仅在分辨率桶为空时参与尺寸计算。
  int get minimumInputPixels => 600000;

  /// 输入分辨率的最大总像素面积；仅在分辨率桶为空时参与尺寸计算。
  int get maximumInputPixels => switch (this) {
    RealtimeModel.x2_0 => 1280000,
    RealtimeModel.x2_0_pro => 2100000,
  };

  /// 输入宽度和高度分别需要对齐的像素倍数；仅在分辨率桶为空时参与尺寸计算。
  int get inputSizeAlignment => 32;

  /// 未指定视频规格时，各媒体来源使用的默认帧率。
  int get defaultFrameRate => switch (this) {
    RealtimeModel.x2_0 => 30,
    RealtimeModel.x2_0_pro => 30,
  };

  /// 摄像头采集使用的默认视频规格。
  RealtimeVideoFormat get defaultCameraVideoFormat => switch (this) {
    RealtimeModel.x2_0 => const RealtimeVideoFormat(
      width: 832,
      height: 1472,
      fps: 30,
    ),
    RealtimeModel.x2_0_pro => const RealtimeVideoFormat(
      width: 1024,
      height: 1920,
      fps: 30,
    ),
  };
}
