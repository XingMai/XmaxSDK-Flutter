import 'dart:convert';

import '../../service/realtime/RealtimeContext.dart';
import '../../service/realtime/RealtimePoint.dart';
import '../../service/realtime/RealtimeVideoFormat.dart';

abstract final class RoomEvent {
  static String start({
    required String userID,
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
  }) => _generation(
    event: 'start',
    userID: userID,
    taskID: taskID,
    videoFormat: videoFormat,
    context: context,
  );

  static String changeCondition({
    required String userID,
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
  }) => _generation(
    event: 'change_condition',
    userID: userID,
    taskID: taskID,
    videoFormat: videoFormat,
    context: context,
  );

  static String stop({required String userID, required String taskID}) =>
      jsonEncode(<String, Object?>{
        'event': 'stop',
        'user_id': userID,
        'uid': taskID,
      });

  static String tracks({
    required String userID,
    required String taskID,
    required List<RealtimePoint> points,
  }) => jsonEncode(<String, Object?>{
    'event': 'tracks',
    'tracks': points.map((point) => <double>[point.x, point.y]).toList(),
    'user_id': userID,
    'uid': taskID,
  });

  static String heartbeat({required String userID}) =>
      jsonEncode(<String, Object?>{'event': 'heartbeat', 'user_id': userID});

  static String _generation({
    required String event,
    required String userID,
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext context,
  }) {
    final params = <String, Object?>{
      'model': 'default',
      'size': <int>[videoFormat.width, videoFormat.height],
      'prompt': context.prompt,
    };
    final referencePath = context.referencePath;
    if (referencePath != null) {
      params['ref_image_path'] = referencePath;
    }

    // Match iOS and Android exactly: omitting `ref_image_path` clears the
    // previous condition, while an explicit JSON null is ignored upstream.
    return jsonEncode(<String, Object?>{
      'event': event,
      'params': params,
      'user_id': userID,
      'uid': taskID,
    });
  }
}
