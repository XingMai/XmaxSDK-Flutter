import '../../foundation/rtc/rtc_managing.dart';
import '../../foundation/rtc/rtc_models.dart';
import '../../service/realtime/realtime_video_format.dart';
import 'encoding_controlling.dart';

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
