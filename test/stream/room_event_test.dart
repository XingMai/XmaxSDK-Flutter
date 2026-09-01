import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeContext.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimePoint.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeVideoFormat.dart';
import 'package:xmax_sdk/src/stream/room/RoomEvent.dart';

void main() {
  const format = RealtimeVideoFormat(width: 1024, height: 576, fps: 30);

  test('start event matches iOS room signaling contract', () {
    final event = jsonDecode(
      RoomEvent.start(
        userID: 'user-1',
        taskID: 'task-1',
        videoFormat: format,
        context: RealtimeContext(
          prompt: 'turn it into ink',
          referencePath: 'cos/ref.png',
        ),
      ),
    );

    expect(event, <String, Object?>{
      'event': 'start',
      'params': <String, Object?>{
        'model': 'default',
        'size': <int>[1024, 576],
        'prompt': 'turn it into ink',
        'ref_image_path': 'cos/ref.png',
      },
      'user_id': 'user-1',
      'uid': 'task-1',
    });
  });

  test('change condition omits a removed reference like iOS', () {
    final event =
        jsonDecode(
              RoomEvent.changeCondition(
                userID: 'user-1',
                taskID: 'task-1',
                videoFormat: format,
                context: RealtimeContext(prompt: 'animate without a reference'),
              ),
            )
            as Map<String, Object?>;
    final params = event['params'] as Map<String, Object?>;

    expect(event['event'], 'change_condition');
    expect(params['prompt'], 'animate without a reference');
    expect(params.containsKey('ref_image_path'), isFalse);
  });

  test('tracks, stop, and heartbeat events match iOS keys', () {
    expect(
      jsonDecode(
        RoomEvent.tracks(
          userID: 'user-1',
          taskID: 'task-1',
          points: const <RealtimePoint>[
            RealtimePoint(x: 10, y: 20),
            RealtimePoint(x: 30, y: 40),
          ],
        ),
      ),
      <String, Object?>{
        'event': 'tracks',
        'tracks': <List<double>>[
          <double>[10, 20],
          <double>[30, 40],
        ],
        'user_id': 'user-1',
        'uid': 'task-1',
      },
    );
    expect(
      jsonDecode(RoomEvent.stop(userID: 'user-1', taskID: 'task-1')),
      <String, Object?>{'event': 'stop', 'user_id': 'user-1', 'uid': 'task-1'},
    );
    expect(jsonDecode(RoomEvent.heartbeat(userID: 'user-1')), <String, Object?>{
      'event': 'heartbeat',
      'user_id': 'user-1',
    });
  });
}
