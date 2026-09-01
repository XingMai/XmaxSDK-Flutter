import '../../service/realtime/RealtimeVideoFormat.dart';

abstract interface class EncodingControlling {
  Future<void> configure(RealtimeVideoFormat videoFormat);
}
