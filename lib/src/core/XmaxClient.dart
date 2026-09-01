import '../foundation/logging/XmaxLogger.dart';
import '../foundation/storage/StorageManager.dart';
import '../service/media/MediaService.dart';
import '../service/media/MediaServicing.dart';
import '../service/network/ApiService.dart';
import '../service/network/ApiServicing.dart';
import '../service/storage/StorageService.dart';
import 'realtime/RealtimeConfiguration.dart';
import 'realtime/XmaxRealtimeManager.dart';
import 'realtime/XmaxRealtimeManaging.dart';
import 'storage/XmaxStorageManager.dart';
import 'storage/XmaxStorageManaging.dart';
import 'XmaxConfiguration.dart';

/// SDK 的统一入口，负责创建实时、存储和媒体服务组件。
final class XmaxClient {
  XmaxClient({required this.configuration})
    : _apiService = ApiService(apiKey: configuration.apiKey) {
    XmaxLogger.configure(options: configuration.loggerOptions);
  }

  XmaxClient.internal({
    required this.configuration,
    required ApiServicing apiService,
  }) : _apiService = apiService {
    XmaxLogger.configure(options: configuration.loggerOptions);
  }

  final XmaxConfiguration configuration;
  final ApiServicing _apiService;

  XmaxRealtimeManaging createRealtimeManager({
    required RealtimeConfiguration options,
  }) => XmaxRealtimeManager(options: options, apiService: _apiService);

  XmaxStorageManaging createStorageManager() {
    configuration.validate();
    return XmaxStorageManager(
      storageService: StorageService(
        apiService: _apiService,
        storageManager: StorageManager(),
      ),
    );
  }

  MediaServicing createMediaService() => MediaService();
}
