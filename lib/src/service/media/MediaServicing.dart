import 'package:flutter/widgets.dart';

import '../../core/realtime/RealtimeModel.dart';

abstract interface class MediaServicing {
  /// 当前媒体服务使用的模型，决定输入尺寸约束。
  RealtimeModel get model;

  /// 按当前模型校验并解析输入尺寸。
  Size resolveModelInputSize(Size size);
}
