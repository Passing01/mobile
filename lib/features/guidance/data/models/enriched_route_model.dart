import 'package:equatable/equatable.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/enriched_maneuver_model.dart';

/// Modèle représentant un itinéraire intégralement enrichi de consignes vocales locales
class EnrichedRouteModel extends Equatable {
  final String mode;
  final double totalDistanceMeters;
  final String totalDurationFormatted;
  final String language;
  final List<EnrichedManeuverModel> enrichedManeuvers;

  const EnrichedRouteModel({
    required this.mode,
    required this.totalDistanceMeters,
    required this.totalDurationFormatted,
    required this.language,
    required this.enrichedManeuvers,
  });

  factory EnrichedRouteModel.fromJson(Map<String, dynamic> json) {
    final maneuversJson = json['enriched_maneuvers'] as List<dynamic>? ?? [];
    return EnrichedRouteModel(
      mode: json['mode'] as String? ?? 'motorcycle',
      totalDistanceMeters:
          (json['total_distance_meters'] as num?)?.toDouble() ?? 0.0,
      totalDurationFormatted:
          json['total_duration_formatted'] as String? ?? '0 min',
      language: json['language'] as String? ?? 'fr',
      enrichedManeuvers: maneuversJson
          .map((m) => EnrichedManeuverModel.fromJson(m as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'total_distance_meters': totalDistanceMeters,
      'total_duration_formatted': totalDurationFormatted,
      'language': language,
      'enriched_maneuvers': enrichedManeuvers.map((m) => m.toJson()).toList(),
    };
  }

  /// Distance totale lisible (ex: 4.2 km)
  String get distanceFormatted {
    if (totalDistanceMeters < 1000) {
      return '${totalDistanceMeters.round()} m';
    } else {
      final km = totalDistanceMeters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  @override
  List<Object?> get props => [
        mode,
        totalDistanceMeters,
        totalDurationFormatted,
        language,
        enrichedManeuvers,
      ];
}
