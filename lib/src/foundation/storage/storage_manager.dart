import 'dart:async';
import 'dart:io';

import 'package:tencentcloud_cos_sdk_plugin_nobeacon/cos.dart';
import 'package:tencentcloud_cos_sdk_plugin_nobeacon/cos_transfer_manger.dart';
import 'package:tencentcloud_cos_sdk_plugin_nobeacon/pigeon.dart';

import '../errors/xmax_error.dart';
import 'storage_managing.dart';
import 'storage_models.dart';

/// 封装腾讯 COS 上传和 HTTP 文件下载能力。
final class StorageManager implements StorageManaging {
  StorageManager({HttpClient? httpClient})
    : _httpClient = httpClient ?? HttpClient();

  final HttpClient _httpClient;

  @override
  Future<StoredFile> upload({
    required StorageUploadSource source,
    required String objectKey,
    required String contentType,
    required StorageConfiguration configuration,
    StorageProgressListener? progress,
  }) async {
    _validateUpload(
      source: source,
      objectKey: objectKey,
      contentType: contentType,
      configuration: configuration,
    );
    final completer = Completer<StoredFile>();
    try {
      final transferManager = await _transferManager(configuration);
      final credential = configuration.credential;
      final now = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      final sessionCredentials = SessionQCloudCredentials(
        secretId: credential.accessKeyID,
        secretKey: credential.secretAccessKey,
        token: credential.sessionToken,
        startTime: now - 60,
        expiredTime: now + 25 * 60,
      );
      final resultListener = ResultListener(
        (headers, result) {
          if (completer.isCompleted) {
            return;
          }
          try {
            final candidate =
                result?.accessUrl ??
                headers?['location'] ??
                headers?['Location'];
            completer.complete(
              StoredFile(
                url: resolveObjectURL(
                  candidate: candidate,
                  configuration: configuration,
                  objectKey: objectKey,
                ),
                objectKey: objectKey,
                etag: result?.eTag ?? headers?['etag'] ?? headers?['ETag'],
              ),
            );
          } catch (error, stackTrace) {
            completer.completeError(error, stackTrace);
          }
        },
        (clientException, serviceException) {
          if (!completer.isCompleted) {
            completer.completeError(
              XmaxError(
                code: XmaxErrorCode.uploadError,
                message:
                    serviceException?.toString() ??
                    clientException?.toString() ??
                    'Storage upload failed',
              ),
            );
          }
        },
      );
      switch (source) {
        case StorageDataUploadSource(:final data):
          await transferManager.upload(
            configuration.bucket,
            objectKey,
            region: configuration.region,
            byteArr: data,
            customHeaders: <String, String>{'Content-Type': contentType},
            sessionCredentials: sessionCredentials,
            resultListener: resultListener,
            progressCallBack: progress,
          );
        case StorageFileUploadSource(:final fileURL):
          await transferManager.upload(
            configuration.bucket,
            objectKey,
            region: configuration.region,
            filePath: fileURL.toFilePath(),
            customHeaders: <String, String>{'Content-Type': contentType},
            sessionCredentials: sessionCredentials,
            resultListener: resultListener,
            progressCallBack: progress,
          );
      }
      return await completer.future;
    } on XmaxError {
      rethrow;
    } catch (error) {
      throw XmaxError(
        code: XmaxErrorCode.uploadError,
        message: error.toString(),
      );
    }
  }

  @override
  Future<DownloadedFile> download({
    required Uri remoteURL,
    required Uri destinationURL,
    StorageProgressListener? progress,
  }) async {
    if (!_isHTTPURL(remoteURL)) {
      throw const XmaxError(
        code: XmaxErrorCode.downloadError,
        message: 'Storage download URL must use HTTP or HTTPS',
      );
    }
    if (!destinationURL.isScheme('file')) {
      throw const XmaxError(
        code: XmaxErrorCode.downloadError,
        message: 'Storage download destination must be a file URL',
      );
    }

    IOSink? sink;
    try {
      final request = await _httpClient.getUrl(remoteURL);
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw XmaxError(
          code: XmaxErrorCode.downloadError,
          message: 'Storage download failed with HTTP ${response.statusCode}',
          httpStatus: response.statusCode,
        );
      }
      final target = File(destinationURL.toFilePath());
      sink = target.openWrite();
      var completed = 0;
      final total = response.contentLength;
      await for (final chunk in response) {
        sink.add(chunk);
        completed += chunk.length;
        if (total >= completed && total > 0) {
          progress?.call(completed, total);
        }
      }
      await sink.flush();
      await sink.close();
      sink = null;
      progress?.call(completed, completed);
      return DownloadedFile(fileURL: destinationURL, byteCount: completed);
    } on XmaxError {
      rethrow;
    } catch (error) {
      throw XmaxError(
        code: XmaxErrorCode.downloadError,
        message: error.toString(),
      );
    } finally {
      await sink?.close();
    }
  }

  Future<CosTransferManger> _transferManager(
    StorageConfiguration configuration,
  ) async {
    final key =
        'xmax-${configuration.region}-'
        '${configuration.endpoint.hashCode}-${configuration.bucket.hashCode}';
    if (Cos().hasTransferManger(key)) {
      return Cos().getTransferManger(key);
    }
    final endpoint = _normalizedEndpoint(configuration.endpoint);
    return Cos().registerTransferManger(
      key,
      CosXmlServiceConfig(
        region: configuration.region,
        isHttps: endpoint == null || endpoint.isScheme('https'),
        host: endpoint?.host,
        port: endpoint?.hasPort == true ? endpoint?.port : null,
      ),
      TransferConfig(),
    );
  }

  void _validateUpload({
    required StorageUploadSource source,
    required String objectKey,
    required String contentType,
    required StorageConfiguration configuration,
  }) {
    final identifier = RegExp(r'^[A-Za-z0-9.-]+$');
    final credential = configuration.credential;
    if (!identifier.hasMatch(configuration.bucket.trim())) {
      throw const XmaxError(
        code: XmaxErrorCode.uploadError,
        message: 'Storage bucket is invalid',
      );
    }
    if (!identifier.hasMatch(configuration.region.trim())) {
      throw const XmaxError(
        code: XmaxErrorCode.uploadError,
        message: 'Storage region is invalid',
      );
    }
    if (objectKey.trim().isEmpty) {
      throw const XmaxError(
        code: XmaxErrorCode.uploadError,
        message: 'Storage object key is invalid',
      );
    }
    if (contentType.trim().isEmpty) {
      throw const XmaxError(
        code: XmaxErrorCode.uploadError,
        message: 'Storage content type cannot be empty',
      );
    }
    if (credential.accessKeyID.trim().isEmpty ||
        credential.secretAccessKey.trim().isEmpty ||
        credential.sessionToken.trim().isEmpty) {
      throw const XmaxError(
        code: XmaxErrorCode.uploadError,
        message: 'Storage temporary credential is incomplete',
      );
    }
    if (source case StorageFileUploadSource(:final fileURL)) {
      if (!fileURL.isScheme('file') ||
          !File(fileURL.toFilePath()).existsSync()) {
        throw const XmaxError(
          code: XmaxErrorCode.uploadError,
          message: 'Storage upload file is unavailable',
        );
      }
    }
  }

  static Uri resolveObjectURL({
    required String? candidate,
    required StorageConfiguration configuration,
    required String objectKey,
  }) {
    final location = candidate?.trim() ?? '';
    if (location.startsWith('//')) {
      final url = Uri.tryParse('https:$location');
      if (url != null) {
        return url;
      }
    }
    final candidateURL = Uri.tryParse(location);
    if (candidateURL != null && _isHTTPURL(candidateURL)) {
      return candidateURL;
    }
    final configuredEndpoint = _normalizedEndpoint(configuration.endpoint);
    final endpoint =
        configuredEndpoint ??
        Uri.parse(
          'https://${configuration.bucket}.cos.'
          '${configuration.region}.myqcloud.com',
        );
    final segments = <String>[
      ...endpoint.pathSegments.where((segment) => segment.isNotEmpty),
      ...objectKey.split('/'),
    ];
    return endpoint.replace(pathSegments: segments);
  }

  static Uri? _normalizedEndpoint(String value) {
    final endpoint = value.trim();
    if (endpoint.isEmpty) {
      return null;
    }
    final uri = Uri.tryParse(
      endpoint.contains('://') ? endpoint : 'https://$endpoint',
    );
    if (uri == null || !_isHTTPURL(uri)) {
      throw const XmaxError(
        code: XmaxErrorCode.uploadError,
        message: 'Storage endpoint is invalid',
      );
    }
    return uri;
  }

  static bool _isHTTPURL(Uri uri) =>
      (uri.isScheme('http') || uri.isScheme('https')) && uri.host.isNotEmpty;
}
