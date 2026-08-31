import 'package:permission_handler/permission_handler.dart';

import '../errors/xmax_error.dart';
import 'permission_managing.dart';

final class PermissionManager implements PermissionManaging {
  const PermissionManager();

  @override
  Future<void> ensureCameraPermission() async {
    var status = await Permission.camera.status;
    if (!status.isGranted) {
      status = await Permission.camera.request();
    }
    if (!status.isGranted) {
      throw const XmaxError(
        code: XmaxErrorCode.cameraPermissionDenied,
        message: 'Camera permission is denied',
      );
    }
  }
}
