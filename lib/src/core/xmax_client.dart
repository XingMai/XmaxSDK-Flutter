import '../foundation/logging/xmax_logger.dart';
import '../foundation/storage/storage_manager.dart';
import '../service/media/media_service.dart';
import '../service/media/media_servicing.dart';
import '../service/network/api_service.dart';
import '../service/network/api_servicing.dart';
import '../service/storage/storage_service.dart';
import 'realtime/realtime_configuration.dart';
import 'realtime/xmax_realtime_manager.dart';
import 'realtime/xmax_realtime_managing.dart';
import 'storage/xmax_storage_manager.dart';
import 'storage/xmax_storage_managing.dart';
import 'xmax_configuration.dart';

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
