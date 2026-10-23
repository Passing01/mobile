import 'package:equatable/equatable.dart';

/// Modèle pour l'envoi de télémétrie anonyme de conduite (vitesse, position, cap)
class TelemetryPingModel extends Equatable {
  final String sessionId;
  final double latitude;
  final double longitude;
  final double speedKmh;
  final double? bearing;

  const TelemetryPingModel({
    required this.sessionId,
    required this.latitude,
    required this.longitude,
    required this.speedKmh,
    this.bearing,
  });

  Map<String, dynamic> toJson() {
    return {
      'session_id': sessionId,
      'latitude': latitude,
      'longitude': longitude,
      'speed_kmh': speedKmh,
      if (bearing != null) 'bearing': bearing,
    };
  }

  factory TelemetryPingModel.fromJson(Map<String, dynamic> json) {
    return TelemetryPingModel(
      sessionId: json['session_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      speedKmh: (json['speed_kmh'] as num).toDouble(),
      bearing: json['bearing'] != null ? (json['bearing'] as num).toDouble() : null,
    );
  }

  @override
  List<Object?> get props => [sessionId, latitude, longitude, speedKmh, bearing];
}

/// Résultat retourné par le backend lors du calcul de congestion
class TrafficSegmentModel extends Equatable {
  final String segmentId;
  final double latitude;
  final double longitude;
  final double averageSpeedKmh;
  final String congestionLevel;
  final int samplesCount;
  final DateTime lastUpdated;

  const TrafficSegmentModel({
    required this.segmentId,
    required this.latitude,
    required this.longitude,
    required this.averageSpeedKmh,
    required this.congestionLevel,
    required this.samplesCount,
    required this.lastUpdated,
  });

  factory TrafficSegmentModel.fromJson(Map<String, dynamic> json) {
    return TrafficSegmentModel(
      segmentId: json['segment_id'] as String,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      averageSpeedKmh: (json['average_speed_kmh'] as num).toDouble(),
      congestionLevel: json['congestion_level'] as String? ?? 'fluid',
      samplesCount: (json['samples_count'] as num?)?.toInt() ?? 1,
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  @override
  List<Object?> get props => [
        segmentId,
        latitude,
        longitude,
        averageSpeedKmh,
        congestionLevel,
        samplesCount,
        lastUpdated,
      ];
}
