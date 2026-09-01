import 'package:flutter/widgets.dart';

import '../../foundation/media/video/VideoContentMode.dart';

final class InteractionFrame {
  const InteractionFrame({
    required this.points,
    required this.viewportSize,
    required this.contentMode,
  });

  final List<Offset> points;
  final Size viewportSize;
  final VideoContentMode contentMode;
}
