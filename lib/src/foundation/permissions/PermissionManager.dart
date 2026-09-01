import 'package:permission_handler/permission_handler.dart';

import '../errors/XmaxError.dart';
import '../logging/XmaxLogger.dart';
import 'PermissionManaging.dart';

final class PermissionManager implements PermissionManaging {
  const PermissionManager();

  @override
  Future<void> ensureCameraPermission() async {
    PermissionStatus status;
    try {
      status = await Permission.camera.status;
      if (!status.isGranted) {
        status = await Permission.camera.request();
      }
    } catch (error) {
      XmaxLogger.error(
        '权限申请失败 (Permission Request Failed)\n└─ 原因：$error',
        category: 'Permission',
      );
      throw const XmaxError(
        code: XmaxErrorCode.cameraPermissionDenied,
        message: 'Camera permission is denied',
      );
    }
    if (!status.isGranted) {
      throw const XmaxError(
        code: XmaxErrorCode.cameraPermissionDenied,
        message: 'Camera permission is denied',
      );
    }
  }
}
