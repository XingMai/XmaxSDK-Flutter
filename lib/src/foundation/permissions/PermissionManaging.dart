abstract interface class PermissionManaging {
  Future<void> ensureCameraPermission();
  Future<void> ensureMicrophonePermission();
}
