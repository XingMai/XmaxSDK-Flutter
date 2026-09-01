import 'dart:math';

import '../../foundation/errors/XmaxError.dart';
import '../../media/interaction/InteractionControlling.dart';
import '../../service/realtime/RealtimeContext.dart';
import '../../service/realtime/RealtimeVideoFormat.dart';
import '../../stream/StreamControlling.dart';

typedef RealtimeTaskIDGenerator = String Function();

final class XmaxRealtimeGenerationManager {
  XmaxRealtimeGenerationManager({
    required InteractionControlling interactionController,
    required StreamControlling streamController,
    RealtimeTaskIDGenerator? taskIDGenerator,
  }) : _interactionController = interactionController,
       _streamController = streamController,
       _taskIDGenerator = taskIDGenerator ?? createTaskID;

  final InteractionControlling _interactionController;
  final StreamControlling _streamController;
  final RealtimeTaskIDGenerator _taskIDGenerator;
  RealtimeContext? _currentContext;

  Future<String> start({
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext? context,
    required void Function() ensureCurrent,
  }) async {
    final resolvedContext = context ?? _currentContext;
    if (resolvedContext == null) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'A realtime context is required for the first generation',
      );
    }

    final taskID = _taskIDGenerator();

    try {
      await _streamController.beginGeneration(
        taskID: taskID,
        videoFormat: videoFormat,
        context: resolvedContext,
      );

      ensureCurrent();

      _interactionController.startInteraction(
        taskID: taskID,
        videoFormat: videoFormat,
      );

      _currentContext = resolvedContext;
      return taskID;
    } catch (error) {
      // The start signal may have reached the room before a later step failed.
      await _streamController.stopGeneration(taskID: taskID);
      throw XmaxError.from(error);
    }
  }

  Future<void> update({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
    required RealtimeContext? context,
  }) async {
    _interactionController.startInteraction(
      taskID: taskID,
      videoFormat: videoFormat,
    );

    if (context == null) {
      return;
    }

    await _streamController.updateGeneration(
      taskID: taskID,
      videoFormat: videoFormat,
      context: context,
    );

    _currentContext = context;
  }

  Future<void> stop({required String taskID}) async {
    _interactionController.stopInteraction();
    await _streamController.stopGeneration(taskID: taskID);
  }

  Future<void> reset({String taskID = ''}) async {
    _currentContext = null;
    await stop(taskID: taskID);
  }

  static String createTaskID() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Encode 128 random bits directly as unpadded base64url, matching iOS.
    const alphabet =
        'ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_';
    final output = StringBuffer('task-');

    for (var index = 0; index < bytes.length; index += 3) {
      final remaining = bytes.length - index;
      final value =
          (bytes[index] << 16) |
          (remaining > 1 ? bytes[index + 1] << 8 : 0) |
          (remaining > 2 ? bytes[index + 2] : 0);
      output.write(alphabet[(value >> 18) & 63]);
      output.write(alphabet[(value >> 12) & 63]);
      if (remaining > 1) output.write(alphabet[(value >> 6) & 63]);
      if (remaining > 2) output.write(alphabet[value & 63]);
    }

    return output.toString();
  }
}
