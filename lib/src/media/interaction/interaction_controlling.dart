import '../../service/realtime/realtime_video_format.dart';
import 'interaction_frame.dart';

abstract interface class InteractionControlling {
  void startInteraction({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
  });
  void stopInteraction();
  void submitInteraction(InteractionFrame frame);
}
