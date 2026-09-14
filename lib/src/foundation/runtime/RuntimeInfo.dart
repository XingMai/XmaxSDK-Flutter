import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';

import '../../XmaxSDKInfo.dart';

/// SDK 运行环境快照，与 iOS/Android 房间信令的 `runtime` 字段同构。
final class RuntimeInfo {
  const RuntimeInfo({
    required this.platform,
    required this.osVersion,
    required this.sdkVersion,
    required this.deviceModel,
  });

  final String platform;
  final String osVersion;
  final String sdkVersion;
  final String deviceModel;

  static RuntimeInfo current = RuntimeInfo(
    platform: Platform.operatingSystem,
    osVersion: Platform.isIOS || Platform.isAndroid
        ? 'unknown'
        : _currentOSVersion(),
    sdkVersion: XmaxSDKInfo.version,
    deviceModel: 'unknown',
  );

  static Future<RuntimeInfo>? _resolution;

  /// 在首次请求或进房前读取设备信息，后续请求复用同一份快照。
  /// 诊断信息不可用时继续使用回退值，不影响业务请求。
  static Future<RuntimeInfo> resolve() => _resolution ??= _resolve();

  static Future<RuntimeInfo> _resolve() async {
    try {
      final deviceInfo = DeviceInfoPlugin();
      if (Platform.isIOS) {
        final info = await deviceInfo.iosInfo.timeout(
          const Duration(seconds: 3),
        );
        current = RuntimeInfo(
          platform: 'ios',
          osVersion: _nonEmpty(info.systemVersion),
          sdkVersion: XmaxSDKInfo.version,
          deviceModel: _nonEmpty(info.utsname.machine),
        );
      } else if (Platform.isAndroid) {
        final info = await deviceInfo.androidInfo.timeout(
          const Duration(seconds: 3),
        );
        current = RuntimeInfo(
          platform: 'android',
          osVersion: _nonEmpty(info.version.release),
          sdkVersion: XmaxSDKInfo.version,
          deviceModel: _nonEmpty(info.model),
        );
      }
    } catch (_) {
      // A missing or slow platform plugin must not block API or RTC traffic.
    }
    return current;
  }

  static String _nonEmpty(String value) =>
      value.trim().isEmpty ? 'unknown' : value.trim();

  Map<String, String> toJson() => <String, String>{
    'platform': platform,
    'os_version': osVersion,
    'sdk_version': sdkVersion,
    'device_model': deviceModel,
  };

  static String _currentOSVersion() {
    final version = Platform.operatingSystemVersion;
    final match = RegExp(r'\d+(?:\.\d+){1,2}').firstMatch(version);
    return match?.group(0) ?? version.trim();
  }
}
