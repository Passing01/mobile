import 'package:equatable/equatable.dart';

/// Requête de création d'une session de partage de trajet
class LiveTrackingCreateRequest {
  final String? destinationName;
  final int durationMinutes;

  const LiveTrackingCreateRequest({
    this.destinationName,
    this.durationMinutes = 120,
  });

  Map<String, dynamic> toJson() {
    return {
      if (destinationName != null) 'destination_name': destinationName,
      'duration_minutes': durationMinutes,
    };
  }
}

/// Données de mise à jour GPS périodique de la session de partage
class LiveTrackingUpdatePayload {
  final double latitude;
  final double longitude;
  final double? speedKmh;
  final double? bearing;

  const LiveTrackingUpdatePayload({
    required this.latitude,
    required this.longitude,
    this.speedKmh,
    this.bearing,
  });

  Map<String, dynamic> toJson() {
    return {
      'latitude': latitude,
      'longitude': longitude,
      if (speedKmh != null) 'speed_kmh': speedKmh,
      if (bearing != null) 'bearing': bearing,
    };
  }
}

/// Modèle représentant une session active de partage de position en direct
class LiveTrackingModel extends Equatable {
  final String token;
  final String userName;
  final String? destinationName;
  final double latitude;
  final double longitude;
  final double? speedKmh;
  final double? bearing;
  final bool isActive;
  final DateTime createdAt;
  final DateTime expiresAt;
  final DateTime lastUpdated;

  const LiveTrackingModel({
    required this.token,
    required this.userName,
    this.destinationName,
    required this.latitude,
    required this.longitude,
    this.speedKmh,
    this.bearing,
    required this.isActive,
    required this.createdAt,
    required this.expiresAt,
    required this.lastUpdated,
  });

  factory LiveTrackingModel.fromJson(Map<String, dynamic> json) {
    return LiveTrackingModel(
      token: json['token'] as String,
      userName: json['user_name'] as String,
      destinationName: json['destination_name'] as String?,
      latitude: (json['latitude'] as num).toDouble(),
      longitude: (json['longitude'] as num).toDouble(),
      speedKmh: json['speed_kmh'] != null ? (json['speed_kmh'] as num).toDouble() : null,
      bearing: json['bearing'] != null ? (json['bearing'] as num).toDouble() : null,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
      expiresAt: DateTime.parse(json['expires_at'] as String),
      lastUpdated: DateTime.parse(json['last_updated'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'token': token,
      'user_name': userName,
      'destination_name': destinationName,
      'latitude': latitude,
      'longitude': longitude,
      'speed_kmh': speedKmh,
      'bearing': bearing,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt.toIso8601String(),
      'last_updated': lastUpdated.toIso8601String(),
    };
  }

  /// Lien public de suivi à partager aux proches
  String shareUrl(String baseUrl) {
    return '$baseUrl/traffic/tracking/$token';
  }

  @override
  List<Object?> get props => [
        token,
        userName,
        destinationName,
        latitude,
        longitude,
        speedKmh,
        bearing,
        isActive,
        createdAt,
        expiresAt,
        lastUpdated,
      ];
}
