import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../foundation/errors/XmaxError.dart';
import 'MediaServicing.dart';

final class MediaService implements MediaServicing {
  static const _minimumModelPixels = 600000;
  static const _maximumModelPixels = 1280000;
  static const _modelSizeAlignment = 32;

  @override
  Size resolveModelInputSize(Size size) {
    final validated = _validatedSize(size);
    final pixels = validated.width * validated.height;
    final double scale;
    final double Function(num) rounding;

    if (pixels < _minimumModelPixels) {
      scale = math.sqrt(_minimumModelPixels / pixels);
      rounding = (value) => value.ceilToDouble();
    } else if (pixels > _maximumModelPixels) {
      scale = math.sqrt(_maximumModelPixels / pixels);
      rounding = (value) => value.floorToDouble();
    } else {
      scale = 1;
      rounding = (value) => value.roundToDouble();
    }

    final width = math.max(
      rounding(validated.width * scale / _modelSizeAlignment).toInt() *
          _modelSizeAlignment,
      _modelSizeAlignment,
    );
    final height = math.max(
      rounding(validated.height * scale / _modelSizeAlignment).toInt() *
          _modelSizeAlignment,
      _modelSizeAlignment,
    );
    return Size(width.toDouble(), height.toDouble());
  }

  Size _validatedSize(Size size) {
    if (!size.width.isFinite ||
        !size.height.isFinite ||
        size.width <= 0 ||
        size.height <= 0) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message:
            'Image width and height must be finite numbers greater than '
            'zero',
      );
    }
    return Size(
      math.max(size.width.roundToDouble(), 1),
      math.max(size.height.roundToDouble(), 1),
    );
  }
}
