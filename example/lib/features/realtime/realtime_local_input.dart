sealed class XLabRealtimeLocalInput {
  const XLabRealtimeLocalInput();
}

final class XLabRealtimeImageInput extends XLabRealtimeLocalInput {
  const XLabRealtimeImageInput({required this.path, required this.name});

  final String path;
  final String name;

  Uri get uri => Uri.file(path);
}
