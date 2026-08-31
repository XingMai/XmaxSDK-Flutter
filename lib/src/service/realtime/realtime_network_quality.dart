enum RealtimeNetworkQualityLevel {
  unknown('Unknown'),
  excellent('Excellent'),
  good('Good'),
  poor('Poor'),
  bad('Bad'),
  veryBad('VeryBad'),
  down('Down');

  const RealtimeNetworkQualityLevel(this.value);

  final String value;
}

final class RealtimeNetworkQuality {
  const RealtimeNetworkQuality({required this.uplink, required this.downlink});

  final RealtimeNetworkQualityLevel uplink;
  final RealtimeNetworkQualityLevel downlink;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RealtimeNetworkQuality &&
          uplink == other.uplink &&
          downlink == other.downlink;

  @override
  int get hashCode => Object.hash(uplink, downlink);
}

typedef RealtimeNetworkQualityListener =
    void Function(RealtimeNetworkQuality quality);
