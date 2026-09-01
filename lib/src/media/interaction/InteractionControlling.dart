import '../../service/realtime/RealtimeVideoFormat.dart';
import 'InteractionFrame.dart';

abstract interface class InteractionControlling {
  void startInteraction({
    required String taskID,
    required RealtimeVideoFormat videoFormat,
  });
  void stopInteraction();
  void submitInteraction(InteractionFrame frame);
}
