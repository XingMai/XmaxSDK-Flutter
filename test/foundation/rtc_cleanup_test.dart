import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:volc_engine_rtc/volc_engine_rtc.dart';
import 'package:xmax_sdk/src/foundation/errors/XmaxError.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcEngineManager.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcManager.dart';
import 'package:xmax_sdk/src/foundation/rtc/RtcModels.dart';

void main() {
  test(
    'room leave and destroy failures cannot retain the engine lease',
    () async {
      final room = _Room();
      final engine = _Engine(room);
      final pool = RtcEngineManager.internal(createEngine: () async => engine);
      final manager = RtcManager(engineManager: pool);
      await manager.initialize();
      room.registrationGate = Completer<int>();
      final joining = manager.joinRoom(
        configuration: const RoomJoinConfiguration(
          roomID: 'room',
          userID: 'user',
          token: 'token',
        ),
      );
      final cancelled = expectLater(joining, throwsA(isA<XmaxError>()));
      await room.registered.future;
      room.failCleanup = true;
      final nextLease = pool.acquire();
      await manager.destroy();
      expect(room.leaveCount, 1);
      expect(room.destroyCount, 1);
      expect(engine.destroyCount, 1);
      room.registrationGate!.completeError(StateError('join cancelled'));
      await cancelled;
      await pool.release(await nextLease);
      await manager.destroy();
      expect(engine.destroyCount, 2);
    },
  );

  test(
    'synchronous engine destruction failure still unblocks queued owners',
    () async {
      final first = _Engine(_Room())..failDestroy = true;
      final second = _Engine(_Room());
      var creations = 0;
      final pool = RtcEngineManager.internal(
        createEngine: () async => creations++ == 0 ? first : second,
      );
      final firstLease = await pool.acquire();
      final pending = pool.acquire();
      await expectLater(pool.release(firstLease), throwsStateError);
      final next = await pending;
      expect(next.engine, same(second));
      await pool.release(next);
      expect(second.destroyCount, 1);
    },
  );
}

class _Engine implements RTCEngine {
  _Engine(this.room);
  final _Room room;
  int destroyCount = 0;
  bool failDestroy = false;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #setRTCEngineEventHandler:
        return Future<int>.value(0);
      case #createRTCRoom:
        return Future<RTCRoom?>.value(room);
      case #destroy:
        destroyCount++;
        if (failDestroy) throw StateError('destroy failed');
        return null;
      default:
        return super.noSuchMethod(invocation);
    }
  }
}

class _Room implements RTCRoom {
  Completer<int>? registrationGate;
  final registered = Completer<void>();
  IRTCRoomEventHandler? listener;
  bool failCleanup = false;
  int leaveCount = 0;
  int destroyCount = 0;

  @override
  dynamic noSuchMethod(Invocation invocation) {
    switch (invocation.memberName) {
      case #setRTCRoomEventHandler:
        listener =
            invocation.positionalArguments.single as IRTCRoomEventHandler;
        registered.complete();
        return registrationGate?.future ?? Future<int>.value(0);
      case #joinRoom:
        listener!.onRoomStateChanged?.call('room', 'user', 0, '');
        return Future<int?>.value(0);
      case #leaveRoom:
        leaveCount++;
        return failCleanup
            ? Future<int?>.error(StateError('leave failed'))
            : Future<int?>.value(0);
      case #destroy:
        destroyCount++;
        return failCleanup
            ? Future<void>.error(StateError('room destroy failed'))
            : Future<void>.value();
      default:
        return super.noSuchMethod(invocation);
    }
  }
}
