import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../../foundation/errors/xmax_error.dart';
import '../../foundation/logging/xmax_logger.dart';
import 'api_servicing.dart';

final class ApiTransportResponse {
  const ApiTransportResponse({required this.statusCode, required this.body});

  final int statusCode;
  final List<int> body;
}

abstract interface class ApiTransport {
  Future<ApiTransportResponse> send({
    required ApiMethod method,
    required Uri url,
    required Map<String, String> headers,
    required List<int>? body,
    required Duration timeout,
  });
}

final class HttpApiTransport implements ApiTransport {
  HttpApiTransport({HttpClient? client}) : _client = client ?? HttpClient();

  final HttpClient _client;

  @override
  Future<ApiTransportResponse> send({
    required ApiMethod method,
    required Uri url,
    required Map<String, String> headers,
    required List<int>? body,
    required Duration timeout,
  }) async {
    final request = await _client.openUrl(method.value, url).timeout(timeout);
    headers.forEach(request.headers.set);
    if (body != null) {
      request.add(body);
    }
    final response = await request.close().timeout(timeout);
    final bytes = await response.fold<List<int>>(
      <int>[],
      (buffer, chunk) => buffer..addAll(chunk),
    );
    return ApiTransportResponse(statusCode: response.statusCode, body: bytes);
  }
}

/// 负责发送 Xmax API 请求并统一处理响应、日志和错误。
final class ApiService implements ApiServicing {
  ApiService({
    required String apiKey,
    Uri? baseURL,
    Duration timeout = defaultTimeoutInterval,
    ApiTransport? transport,
  }) : _apiKey = apiKey.trim(),
       _baseURL = baseURL ?? defaultBaseURL,
       _timeout = timeout,
       _transport = transport ?? HttpApiTransport();

  static final Uri defaultBaseURL = Uri.parse(
    'https://cloud.xmax.22duck.cn/open/api/v1',
  );
  static const Duration defaultTimeoutInterval = Duration(seconds: 15);

  final String _apiKey;
  final Uri _baseURL;
  final Duration _timeout;
  final ApiTransport _transport;

  @override
  Future<T> request<T>(
    ApiMethod method, {
    required String path,
    Object? body,
    required T Function(Object? json) decode,
  }) async {
    _validateConfiguration();
    final url = _makeURL(path);
    final encodedBody = body == null ? null : utf8.encode(jsonEncode(body));
    final stopwatch = Stopwatch()..start();

    final ApiTransportResponse response;
    try {
      response = await _transport.send(
        method: method,
        url: url,
        headers: <String, String>{
          HttpHeaders.acceptHeader: ContentType.json.mimeType,
          HttpHeaders.contentTypeHeader: ContentType.json.mimeType,
          'X-Api-Key': _apiKey,
        },
        body: encodedBody,
        timeout: _timeout,
      );
    } on TimeoutException catch (error) {
      throw XmaxError(
        code: XmaxErrorCode.networkError,
        message: 'HTTP request failed: $error',
      );
    } on XmaxError {
      rethrow;
    } catch (error) {
      throw XmaxError(
        code: XmaxErrorCode.networkError,
        message: 'HTTP request failed: $error',
      );
    }

    try {
      final value = _parseResponse(response, decode);
      XmaxLogger.debug(
        '${method.value} $path ${response.statusCode} '
        '${stopwatch.elapsedMilliseconds}ms',
        category: 'API',
      );
      return value;
    } on XmaxError {
      rethrow;
    } catch (error) {
      throw XmaxError(
        code: XmaxErrorCode.apiError,
        message: error.toString(),
        httpStatus: response.statusCode,
      );
    }
  }

  void _validateConfiguration() {
    if (_apiKey.isEmpty) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidAPIKey,
        message: 'API key cannot be empty',
      );
    }
    if (_baseURL.scheme.toLowerCase() != 'https' ||
        _baseURL.host.isEmpty ||
        _timeout <= Duration.zero) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'API service configuration is invalid',
      );
    }
  }

  Uri _makeURL(String path) {
    final normalizedPath = path.trim();
    if (normalizedPath.isEmpty ||
        normalizedPath.contains('://') ||
        normalizedPath.startsWith('//')) {
      throw const XmaxError(
        code: XmaxErrorCode.invalidConfiguration,
        message: 'API request path is invalid',
      );
    }
    final basePath = _baseURL.path.endsWith('/')
        ? _baseURL.path.substring(0, _baseURL.path.length - 1)
        : _baseURL.path;
    final relativePath = normalizedPath.startsWith('/')
        ? normalizedPath
        : '/$normalizedPath';
    return _baseURL.replace(path: '$basePath$relativePath');
  }

  T _parseResponse<T>(
    ApiTransportResponse response,
    T Function(Object? json) decode,
  ) {
    final Object? json;
    try {
      json = jsonDecode(utf8.decode(response.body));
    } catch (_) {
      throw XmaxError(
        code: XmaxErrorCode.apiError,
        message: 'Server returned invalid JSON',
        httpStatus: response.statusCode,
      );
    }
    if (json is! Map<String, dynamic>) {
      throw XmaxError(
        code: XmaxErrorCode.apiError,
        message: 'Server returned invalid JSON',
        httpStatus: response.statusCode,
      );
    }

    final success = json['success'];
    if (response.statusCode < 200 ||
        response.statusCode >= 300 ||
        success != true) {
      final rawMessage = json['message'];
      final message = rawMessage is String && rawMessage.trim().isNotEmpty
          ? rawMessage.trim()
          : 'Xmax API request failed';
      throw XmaxError(
        code: XmaxErrorCode.apiError,
        message: message,
        apiCode: json['code'] is int ? json['code'] as int : null,
        httpStatus: response.statusCode,
      );
    }

    if (!json.containsKey('data') || json['data'] == null) {
      throw XmaxError(
        code: XmaxErrorCode.apiError,
        message: 'Server returned invalid response data',
        httpStatus: response.statusCode,
      );
    }
    try {
      return decode(json['data']);
    } catch (_) {
      throw XmaxError(
        code: XmaxErrorCode.apiError,
        message: 'Server returned invalid response data',
        httpStatus: response.statusCode,
      );
    }
  }
}
