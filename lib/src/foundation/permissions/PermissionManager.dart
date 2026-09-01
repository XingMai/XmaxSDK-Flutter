import 'package:permission_handler/permission_handler.dart';

import '../errors/ErrorNormalizer.dart';
import '../errors/XmaxError.dart';
import '../logging/XmaxLogger.dart';
import 'PermissionManaging.dart';

final class PermissionManager implements PermissionManaging {
  const PermissionManager();

  @override
  Future<void> ensureCameraPermission() => _ensurePermission(
    Permission.camera,
    errorCode: XmaxErrorCode.cameraPermissionDenied,
    errorMessage: 'Camera permission is unavailable or was denied',
  );

  @override
  Future<void> ensureMicrophonePermission() => _ensurePermission(
    Permission.microphone,
    errorCode: XmaxErrorCode.microphonePermissionDenied,
    errorMessage: 'Microphone permission is unavailable or was denied',
  );

  Future<void> _ensurePermission(
    Permission permission, {
    required XmaxErrorCode errorCode,
    required String errorMessage,
  }) async {
    PermissionStatus status;
    try {
      status = await permission.status;
      if (!status.isGranted) {
        status = await permission.request();
      }
    } catch (error) {
      XmaxLogger.error(
        category: XmaxLoggerCategory.permission,
        message:
            '权限申请失败 (Permission Request Failed)\n'
            '└─ 原因：${ErrorNormalizer.description(error)}',
      );
      throw XmaxError(code: errorCode, message: errorMessage);
    }
    if (!status.isGranted) {
      throw XmaxError(code: errorCode, message: errorMessage);
    }
  }
}
