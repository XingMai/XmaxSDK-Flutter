import 'dart:convert';
import 'dart:ui';

import '../../foundation/runtime/RuntimeInfo.dart';
import '../../service/realtime/RealtimeContext.dart';
import '../../service/realtime/RealtimePoint.dart';
import '../../service/realtime/RealtimeVideoFormat.dart';

abstract final class RoomEvent {
  static String start({
    required String userID,
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
    Size? targetSize,
  }) => _generation(
    event: 'start',
    userID: userID,
    taskID: taskID,
    videoFormat: videoFormat,
    context: context,
    targetSize: targetSize,
  );

  static String changeCondition({
    required String userID,
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
    Size? targetSize,
  }) => _generation(
    event: 'change_condition',
    userID: userID,
    taskID: taskID,
    videoFormat: videoFormat,
    context: context,
    targetSize: targetSize,
  );

  static String changeTargetSize({
    required String userID,
    required String taskID,
    required Size targetSize,
  }) => _encode(<String, Object?>{
    'event': 'change_target_size',
    'params': <String, Object?>{'target_size': _size(targetSize)},
    'user_id': userID,
    'uid': taskID,
  });

  static String stop({required String userID, required String taskID}) =>
      _encode(<String, Object?>{
        'event': 'stop',
        'user_id': userID,
        'uid': taskID,
      });

  static String tracks({
    required String userID,
    required String taskID,
    required List<RealtimePoint> points,
  }) => _encode(<String, Object?>{
    'event': 'tracks',
    'tracks': points.map((point) => <double>[point.x, point.y]).toList(),
    'user_id': userID,
    'uid': taskID,
  });

  static String heartbeat({required String userID}) =>
      _encode(<String, Object?>{'event': 'heartbeat', 'user_id': userID});

  static String _generation({
    required String event,
    required String userID,
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
    Size? targetSize,
  }) {
    final params = <String, Object?>{
      'model': 'default',
      'size': <int>[videoFormat.width, videoFormat.height],
      'prompt': context.prompt,
    };
    final referencePath = context.referencePath;
    if (targetSize != null) {
      params['target_size'] = _size(targetSize);
    }
    if (referencePath != null) {
      params['ref_image_path'] = referencePath;
    }

    // Match iOS and Android exactly: omitting `ref_image_path` clears the
    // previous condition, while an explicit JSON null is ignored upstream.
    return _encode(<String, Object?>{
      'event': event,
      'params': params,
      'user_id': userID,
      'uid': taskID,
    });
  }

  static List<int> _size(Size value) => <int>[
    value.width.toInt(),
    value.height.toInt(),
  ];

  static String _encode(Map<String, Object?> event) => jsonEncode(
    <String, Object?>{...event, 'runtime': RuntimeInfo.current.toJson()},
  );
}
