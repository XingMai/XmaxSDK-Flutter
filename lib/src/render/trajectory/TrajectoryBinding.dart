import '../../media/interaction/InteractionFrame.dart';

final class TrajectoryBinding {
  const TrajectoryBinding({required this.interactionListener});

  final void Function(InteractionFrame frame) interactionListener;
}
