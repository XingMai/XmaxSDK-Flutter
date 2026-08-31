/// SDK 向接入方暴露的统一错误码。
enum XmaxErrorCode {
  invalidAPIKey('INVALID_API_KEY'),
  invalidConfiguration('INVALID_CONFIGURATION'),
  internalError('INTERNAL_ERROR'),
  networkError('NETWORK_ERROR'),
  apiError('API_ERROR'),
  sessionError('SESSION_ERROR'),
  rtcError('RTC_ERROR'),
  mediaError('MEDIA_ERROR'),
  frameInterpolationUnsupported('FRAME_INTERPOLATION_UNSUPPORTED'),
  cameraPermissionDenied('CAMERA_PERMISSION_DENIED'),
  microphonePermissionDenied('MICROPHONE_PERMISSION_DENIED'),
  uploadError('UPLOAD_ERROR'),
  downloadError('DOWNLOAD_ERROR'),
  unsafeImage('UNSAFE_IMAGE'),
  cancelled('CANCELLED'),
  timeout('TIMEOUT');

  const XmaxErrorCode(this.value);

  final String value;
}

/// 表示 SDK 抛出或回调给接入方的统一错误。
final class XmaxError implements Exception {
  const XmaxError({
    required this.code,
    required this.message,
    this.apiCode,
    this.httpStatus,
  });

  final XmaxErrorCode code;
  final String message;
  final int? apiCode;
  final int? httpStatus;

  static XmaxError from(Object error) {
    if (error is XmaxError) {
      return error;
    }
    return XmaxError(
      code: XmaxErrorCode.internalError,
      message: error.toString(),
    );
  }

  @override
  String toString() => 'XmaxError(${code.value}): $message';

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is XmaxError &&
          code == other.code &&
          message == other.message &&
          apiCode == other.apiCode &&
          httpStatus == other.httpStatus;

  @override
  int get hashCode => Object.hash(code, message, apiCode, httpStatus);
}
