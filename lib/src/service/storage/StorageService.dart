import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import '../../foundation/errors/XmaxError.dart';
import '../../foundation/logging/XmaxLogger.dart';
import '../../foundation/storage/StorageManaging.dart';
import '../../foundation/storage/StorageModels.dart';
import '../network/ApiServicing.dart';
import 'StorageServicing.dart';

enum _StorageMediaType {
  image('image', 'Image'),
  video('video', 'Video');

  const _StorageMediaType(this.value, this.displayName);

  final String value;
  final String displayName;
}

final class StorageService implements StorageServicing {
  StorageService({
    required ApiServicing apiService,
    required StorageManaging storageManager,
    DateTime Function()? dateGenerator,
    String Function()? identifierGenerator,
  }) : _apiService = apiService,
       _storageManager = storageManager,
       _dateGenerator = dateGenerator ?? DateTime.now,
       _identifierGenerator = identifierGenerator ?? _makeIdentifier;

  final ApiServicing _apiService;
  final StorageManaging _storageManager;
  final DateTime Function() _dateGenerator;
  final String Function() _identifierGenerator;

  @override
  Future<StoredFile> uploadImage({
    required Uint8List data,
    required String fileName,
    required String contentType,
    StorageProgressListener? progress,
  }) async => _upload(
    source: StorageDataUploadSource(data),
    fileName: fileName,
    contentType: contentType,
    mediaType: _StorageMediaType.image,
    checksSafety: false,
    progress: progress,
  );

  @override
  Future<StoredFile> uploadImageFile({
    required Uri fileURL,
    String? contentType,
    StorageProgressListener? progress,
  }) async => _upload(
    source: StorageFileUploadSource(fileURL),
    fileName: _fileName(fileURL),
    contentType: contentType ?? _inferImageContentType(_fileName(fileURL)),
    mediaType: _StorageMediaType.image,
    checksSafety: false,
    progress: progress,
  );

  @override
  Future<StoredFile> uploadImageWithSafetyCheck({
    required Uint8List data,
    required String fileName,
    required String contentType,
    StorageProgressListener? progress,
  }) => _upload(
    source: StorageDataUploadSource(data),
    fileName: fileName,
    contentType: contentType,
    mediaType: _StorageMediaType.image,
    checksSafety: true,
    progress: progress,
  );

  @override
  Future<StoredFile> uploadImageFileWithSafetyCheck({
    required Uri fileURL,
    String? contentType,
    StorageProgressListener? progress,
  }) async => _upload(
    source: StorageFileUploadSource(fileURL),
    fileName: _fileName(fileURL),
    contentType: contentType ?? _inferImageContentType(_fileName(fileURL)),
    mediaType: _StorageMediaType.image,
    checksSafety: true,
    progress: progress,
  );

  @override
  Future<StoredFile> uploadVideo({
    required Uint8List data,
    required String fileName,
    required String contentType,
    StorageProgressListener? progress,
  }) => _upload(
    source: StorageDataUploadSource(data),
    fileName: fileName,
    contentType: contentType,
    mediaType: _StorageMediaType.video,
    checksSafety: false,
    progress: progress,
  );

  @override
  Future<StoredFile> uploadVideoFile({
    required Uri fileURL,
    String? contentType,
    StorageProgressListener? progress,
  }) async => _upload(
    source: StorageFileUploadSource(fileURL),
    fileName: _fileName(fileURL),
    contentType: contentType ?? _inferVideoContentType(_fileName(fileURL)),
    mediaType: _StorageMediaType.video,
    checksSafety: false,
    progress: progress,
  );

  @override
  Future<DownloadedFile> downloadImage({
    required Uri remoteURL,
    required Uri destinationURL,
    StorageProgressListener? progress,
  }) => _download(
    remoteURL: remoteURL,
    destinationURL: destinationURL,
    progress: progress,
  );

  @override
  Future<DownloadedFile> downloadVideo({
    required Uri remoteURL,
    required Uri destinationURL,
    StorageProgressListener? progress,
  }) => _download(
    remoteURL: remoteURL,
    destinationURL: destinationURL,
    progress: progress,
  );

  Future<StoredFile> _upload({
    required StorageUploadSource source,
    required String fileName,
    required String contentType,
    required _StorageMediaType mediaType,
    required bool checksSafety,
    StorageProgressListener? progress,
  }) async {
    final startedAt = DateTime.now();
    try {
      final safeName = _validateUpload(
        source: source,
        fileName: fileName,
        contentType: contentType,
        mediaType: mediaType,
      );
      final byteCount = _sourceByteCount(source);
      XmaxLogger.info(
        '开始上传 (Upload Started)\n'
        '├─ 类型：${mediaType.value}\n'
        '├─ 分辨率：--\n'
        '├─ 大小：${_formatByteCount(byteCount)}\n'
        '└─ 安全检测：$checksSafety',
        category: 'Storage',
      );

      final temporary = await _fetchStorageConfiguration();
      final objectKey = _makeObjectKey(temporary.prefix, safeName);

      final stored = await _storageManager.upload(
        source: source,
        objectKey: objectKey,
        contentType: contentType.trim(),
        configuration: temporary.configuration,
        progress: progress,
      );

      final StoredFile result;
      if (checksSafety) {
        // Safety checking happens after COS upload because the API checks a URL.
        final checkedURL = await _checkImage(stored.url);
        result = StoredFile(
          url: checkedURL,
          objectKey: stored.objectKey,
          etag: stored.etag,
        );
      } else {
        result = stored;
      }

      XmaxLogger.info(
        '上传完成 (Upload Completed)\n'
        '├─ 地址：${result.url}\n'
        '└─ 耗时：${_formatDuration(startedAt)}',
        category: 'Storage',
      );
      return result;
    } on XmaxError catch (error) {
      _logUploadFailure(error, startedAt);
      rethrow;
    } catch (error) {
      final uploadError = XmaxError(
        code: XmaxErrorCode.uploadError,
        message: error.toString(),
      );
      _logUploadFailure(uploadError, startedAt);
      throw uploadError;
    }
  }

  static int _sourceByteCount(StorageUploadSource source) => switch (source) {
    StorageDataUploadSource(:final data) => data.length,
    StorageFileUploadSource(:final fileURL) => File(
      fileURL.toFilePath(),
    ).lengthSync(),
  };

  static String _formatByteCount(int byteCount) {
    final count = byteCount.toDouble();
    if (byteCount < 1024) return '$byteCount B';
    if (byteCount < 1024 * 1024) {
      return '${(count / 1024).toStringAsFixed(1)} KB';
    }
    if (byteCount < 1024 * 1024 * 1024) {
      return '${(count / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(count / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String _formatDuration(DateTime startedAt) {
    final milliseconds = DateTime.now().difference(startedAt).inMilliseconds;
    if (milliseconds < 1000) return '$milliseconds ms';
    return '${(milliseconds / 1000).toStringAsFixed(2)} s';
  }

  static void _logUploadFailure(XmaxError error, DateTime startedAt) {
    XmaxLogger.error(
      '上传失败 (Upload Failed)\n'
      '├─ 错误码：${error.code.value}\n'
      '├─ 原因：${error.message}\n'
      '└─ 耗时：${_formatDuration(startedAt)}',
      category: 'Storage',
    );
  }

  Future<DownloadedFile> _download({
    required Uri remoteURL,
    required Uri destinationURL,
    StorageProgressListener? progress,
  }) async {
    _validateDownload(remoteURL, destinationURL);
    return _storageManager.download(
      remoteURL: remoteURL,
      destinationURL: destinationURL,
      progress: progress,
    );
  }

  Future<_TemporaryStorageConfiguration> _fetchStorageConfiguration() async {
    final payload = await _apiService.get<Map<String, dynamic>>(
      '/cos/sts',
      (json) => Map<String, dynamic>.from(json! as Map),
    );

    const message = 'Invalid storage credential payload';
    final credentials = payload['credentials'];
    final bucket = _requiredString(payload['bucket']);
    final region = _requiredString(payload['region']);
    final endpoint = _normalizedString(payload['endpoint']);
    final prefix = _normalizedString(payload['prefix']);

    if (credentials is! Map ||
        bucket == null ||
        region == null ||
        endpoint == null ||
        prefix == null) {
      throw const XmaxError(code: XmaxErrorCode.apiError, message: message);
    }

    final accessKeyID = _requiredString(credentials['accessKeyId']);
    final secretAccessKey = _requiredString(credentials['secretAccessKey']);
    final sessionToken = _requiredString(credentials['sessionToken']);

    if (accessKeyID == null ||
        secretAccessKey == null ||
        sessionToken == null) {
      throw const XmaxError(code: XmaxErrorCode.apiError, message: message);
    }

    return _TemporaryStorageConfiguration(
      prefix: prefix,
      configuration: StorageConfiguration(
        bucket: bucket,
        region: region,
        endpoint: endpoint,
        credential: StorageCredential(
          accessKeyID: accessKeyID,
          secretAccessKey: secretAccessKey,
          sessionToken: sessionToken,
        ),
      ),
    );
  }

  Future<Uri> _checkImage(Uri url) async {
    final payload = await _apiService.post<Map<String, dynamic>>(
      '/cos/image/check',
      (json) => Map<String, dynamic>.from(json! as Map),
      body: <String, Object?>{'url': url.toString()},
    );

    const message = 'Invalid image safety check payload';
    final safe = payload['safe'];

    if (safe is! bool) {
      throw const XmaxError(code: XmaxErrorCode.apiError, message: message);
    }

    if (!safe) {
      throw const XmaxError(
        code: XmaxErrorCode.unsafeImage,
        message: 'The image did not pass the safety check',
      );
    }

    final value = _normalizedString(payload['url']);
    final checkedURL = value == null ? null : Uri.tryParse(value);

    if (checkedURL == null || !_isHTTPURL(checkedURL)) {
      throw const XmaxError(code: XmaxErrorCode.apiError, message: message);
    }
    return checkedURL;
  }

  String _validateUpload({
    required StorageUploadSource source,
    required String fileName,
    required String contentType,
    required _StorageMediaType mediaType,
  }) {
    switch (source) {
      case StorageDataUploadSource(:final data):
        if (data.isEmpty) {
          throw XmaxError(
            code: XmaxErrorCode.invalidConfiguration,
            message: '${mediaType.displayName} data cannot be empty',
          );
        }
      case StorageFileUploadSource(:final fileURL):
        if (!fileURL.isScheme('file') ||
            fileURL.toFilePath().isEmpty ||
            !File(fileURL.toFilePath()).existsSync()) {
          throw XmaxError(
            code: XmaxErrorCode.invalidConfiguration,
            message:
                '${mediaType.displayName} file URL must reference an '
                'existing file',
          );
        }
    }

    if (!contentType.trim().toLowerCase().startsWith('${mediaType.value}/')) {
      throw XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message:
            '${mediaType.displayName} content type must begin with '
            '${mediaType.value}/',
      );
    }

    final safeName = _sanitizeFileName(fileName);

    if (safeName.isEmpty) {
      throw XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: '${mediaType.displayName} file name cannot be empty',
      );
    }

    return safeName;
  }

  void _validateDownload(Uri remoteURL, Uri destinationURL) {
    if (!_isHTTPURL(remoteURL)) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'Invalid download URL',
      );
    }

    if (!destinationURL.isScheme('file') || destinationURL.path.isEmpty) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'Download destination URL must be a file URL',
      );
    }
  }

  String _inferImageContentType(String fileName) =>
      _inferContentType(fileName, const <String, String>{
        'jpg': 'image/jpeg',
        'jpeg': 'image/jpeg',
        'jpe': 'image/jpeg',
        'png': 'image/png',
        'gif': 'image/gif',
        'webp': 'image/webp',
        'heic': 'image/heic',
        'heif': 'image/heif',
        'bmp': 'image/bmp',
        'svg': 'image/svg+xml',
        'tif': 'image/tiff',
        'tiff': 'image/tiff',
        'avif': 'image/avif',
      }, 'image');

  String _inferVideoContentType(String fileName) =>
      _inferContentType(fileName, const <String, String>{
        'mp4': 'video/mp4',
        'mov': 'video/quicktime',
        'm4v': 'video/x-m4v',
        'webm': 'video/webm',
        'avi': 'video/x-msvideo',
        'mkv': 'video/x-matroska',
        '3gp': 'video/3gpp',
        '3g2': 'video/3gpp2',
        'ts': 'video/mp2t',
      }, 'video');

  String _inferContentType(
    String fileName,
    Map<String, String> types,
    String mediaType,
  ) {
    final dot = fileName.lastIndexOf('.');
    final extension = dot < 0 ? '' : fileName.substring(dot + 1).toLowerCase();
    final contentType = types[extension];

    if (contentType == null) {
      throw XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'Unable to infer $mediaType content type from file extension',
      );
    }

    return contentType;
  }

  String _sanitizeFileName(String value) {
    var result = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9._-]+'), '_')
        .replaceAll(RegExp('_+'), '_');

    result = result.replaceAll(RegExp(r'^[._-]+|[._-]+$'), '');
    return result;
  }

  String _makeObjectKey(String prefix, String fileName) =>
      '$prefix${_dateGenerator().millisecondsSinceEpoch}_'
      '${_identifierGenerator().toLowerCase()}_$fileName';

  static String _fileName(Uri uri) {
    if (uri.pathSegments.isEmpty) {
      return '';
    }
    return uri.pathSegments.last;
  }

  static String? _normalizedString(Object? value) =>
      value is String ? value.trim() : null;

  static String? _requiredString(Object? value) {
    final normalized = _normalizedString(value);
    return normalized == null || normalized.isEmpty ? null : normalized;
  }

  static bool _isHTTPURL(Uri uri) =>
      (uri.isScheme('https') || uri.isScheme('http')) &&
      uri.host.trim().isNotEmpty;

  static String _makeIdentifier() {
    final random = Random.secure();
    final bytes = List<int>.generate(16, (_) => random.nextInt(256));

    // Set RFC 4122 version and variant bits before formatting the UUID.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    final value = bytes
        .map((byte) => byte.toRadixString(16).padLeft(2, '0'))
        .join();

    return '${value.substring(0, 8)}-${value.substring(8, 12)}-'
        '${value.substring(12, 16)}-${value.substring(16, 20)}-'
        '${value.substring(20)}';
  }
}

final class _TemporaryStorageConfiguration {
  const _TemporaryStorageConfiguration({
    required this.prefix,
    required this.configuration,
  });

  final String prefix;
  final StorageConfiguration configuration;
}
