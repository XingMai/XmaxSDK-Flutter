enum ApiMethod {
  get('GET'),
  post('POST'),
  put('PUT'),
  delete('DELETE');

  const ApiMethod(this.value);

  final String value;
}

abstract interface class ApiServicing {
  Future<T> request<T>(
    ApiMethod method, {
    required String path,
    Object? body,
    required T Function(Object? json) decode,
  });
}

extension ApiServicingConvenience on ApiServicing {
  Future<T> get<T>(String path, T Function(Object? json) decode) =>
      request(ApiMethod.get, path: path, decode: decode);

  Future<T> post<T>(
    String path,
    T Function(Object? json) decode, {
    Object? body,
  }) => request(ApiMethod.post, path: path, body: body, decode: decode);

  Future<T> put<T>(
    String path,
    T Function(Object? json) decode, {
    Object? body,
  }) => request(ApiMethod.put, path: path, body: body, decode: decode);

  Future<T> delete<T>(String path, T Function(Object? json) decode) =>
      request(ApiMethod.delete, path: path, decode: decode);
}
