import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../core/realtime/RealtimeModel.dart';
import '../../foundation/errors/XmaxError.dart';
import 'MediaServicing.dart';

final class MediaService implements MediaServicing {
  MediaService({this.model = RealtimeModel.x2_0});

  @override
  final RealtimeModel model;

  @override
  Size resolveModelInputSize(Size size) {
    final buckets = model.resolutionBuckets;
    if (buckets.isNotEmpty) {
      if (buckets.contains(size)) return size;

      final supportedSizes = buckets
          .map((bucket) => '${bucket.width.toInt()}×${bucket.height.toInt()}')
          .join(', ');
      throw XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message:
            'Model ${model.value} does not support input resolution '
            '${size.width}×${size.height}. Supported resolutions: '
            '$supportedSizes',
      );
    }

    final validated = _validatedSize(size);
    final pixels = validated.width * validated.height;
    final double scale;
    final double Function(num) rounding;

    // Scale into the model's pixel budget before aligning both dimensions.
    if (pixels < model.minimumInputPixels) {
      scale = math.sqrt(model.minimumInputPixels / pixels);
      rounding = (value) => value.ceilToDouble();
    } else if (pixels > model.maximumInputPixels) {
      scale = math.sqrt(model.maximumInputPixels / pixels);
      rounding = (value) => value.floorToDouble();
    } else {
      scale = 1;
      rounding = (value) => value.roundToDouble();
    }

    final alignment = model.inputSizeAlignment;
    final width = math.max(
      rounding(validated.width * scale / alignment).toInt() * alignment,
      alignment,
    );
    final height = math.max(
      rounding(validated.height * scale / alignment).toInt() * alignment,
      alignment,
    );

    final alignedPixels = width * height;
    if (alignedPixels >= model.minimumInputPixels &&
        alignedPixels <= model.maximumInputPixels) {
      return Size(width.toDouble(), height.toDouble());
    }

    // Alignment can cross a pixel limit. Choose the nearest valid size.
    return _boundedAlignedSize(
      width: validated.width * scale,
      height: validated.height * scale,
    );
  }

  Size _boundedAlignedSize({required double width, required double height}) {
    final alignment = model.inputSizeAlignment;
    final unitPixels = alignment * alignment;
    final minimumUnits =
        (model.minimumInputPixels + unitPixels - 1) ~/ unitPixels;
    final maximumUnits = model.maximumInputPixels ~/ unitPixels;
    var bestSize = Size.zero;
    var bestDistance = double.infinity;

    for (var widthUnits = 1; widthUnits <= maximumUnits; widthUnits += 1) {
      final minimumHeight = (minimumUnits + widthUnits - 1) ~/ widthUnits;
      final maximumHeight = maximumUnits ~/ widthUnits;
      if (minimumHeight > maximumHeight) continue;

      final heightUnits = (height / alignment).round().clamp(
        minimumHeight,
        maximumHeight,
      );
      final candidateWidth = (widthUnits * alignment).toDouble();
      final candidateHeight = (heightUnits * alignment).toDouble();
      final distance =
          math.pow((candidateWidth - width) / width, 2) +
          math.pow((candidateHeight - height) / height, 2);
      if (distance < bestDistance) {
        bestDistance = distance.toDouble();
        bestSize = Size(candidateWidth, candidateHeight);
      }
    }

    return bestSize;
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
