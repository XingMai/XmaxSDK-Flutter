import 'package:flutter_test/flutter_test.dart';
import 'package:xmax_sdk/src/service/network/ApiServicing.dart';
import 'package:xmax_sdk/src/service/realtime/RealtimeSessionService.dart';
import 'package:xmax_sdk/xmax_sdk.dart';

void main() {
  test('x2.0-pro session request sends the iOS model identifier', () async {
    final api = _RecordingApiService();
    final service = RealtimeSessionService(apiService: api);

    final session = await service.createSession(model: RealtimeModel.x2_0_pro);

    expect(api.method, ApiMethod.post);
    expect(api.path, '/session');
    expect(api.body, <String, Object?>{'model': 'x2.0-pro'});
    expect(session.id, 'session-pro');
  });
}

final class _RecordingApiService implements ApiServicing {
  ApiMethod? method;
  String? path;
  Object? body;

  @override
  Future<T> request<T>(
    ApiMethod method, {
    required String path,
    Object? body,
    required T Function(Object? json) decode,
  }) async {
    this.method = method;
    this.path = path;
    this.body = body;
    return decode(<String, Object?>{
      'sessionUid': 'session-pro',
      'userUid': 'user-pro',
      'modelExtra': <String, String>{
        'room_id': 'room-pro',
        'room_token': 'token-pro',
      },
    });
  }
}
