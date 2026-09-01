import '../../foundation/rtc/RtcManaging.dart';
import '../../foundation/rtc/RtcModels.dart';
import '../../service/realtime/RealtimeVideoFormat.dart';
import 'EncodingControlling.dart';

final class EncodingController implements EncodingControlling {
  const EncodingController({required RtcManaging rtcManager})
    : _rtcManager = rtcManager;

  final RtcManaging _rtcManager;

  @override
  Future<void> configure(RealtimeVideoFormat videoFormat) async {
    videoFormat.validate();
    await _rtcManager.configureVideoEncoding(
      VideoEncodingConfiguration.fromVideoFormat(videoFormat),
    );
  }
}
