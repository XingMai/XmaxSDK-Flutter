import '../../service/realtime/realtime_video_format.dart';

abstract interface class EncodingControlling {
  Future<void> configure(RealtimeVideoFormat videoFormat);
}
