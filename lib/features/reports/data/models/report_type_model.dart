import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Modèle représentant un type d'incident routier retourné par le backend QvGestion
class ReportTypeModel extends Equatable {
  final String typeIncident;
  final String label;
  final String description;
  final double defaultDurationHours;

  const ReportTypeModel({
    required this.typeIncident,
    required this.label,
    required this.description,
    required this.defaultDurationHours,
  });

  factory ReportTypeModel.fromJson(Map<String, dynamic> json) {
    return ReportTypeModel(
      typeIncident: json['type_incident'] as String? ?? 'unknown',
      label: json['label'] as String? ?? 'Incident routier',
      description: json['description'] as String? ?? '',
      defaultDurationHours: (json['default_duration_hours'] as num?)?.toDouble() ?? 2.0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type_incident': typeIncident,
      'label': label,
      'description': description,
      'default_duration_hours': defaultDurationHours,
    };
  }

  /// Icône Material adaptée au type d'obstacle burkinabè
  IconData get iconData {
    switch (typeIncident) {
      case 'road_closed':
        return Icons.block_rounded;
      case 'flooding':
        return Icons.water_drop_rounded;
      case 'accident':
        return Icons.car_crash_rounded;
      case 'pothole':
        return Icons.warning_amber_rounded;
      case 'traffic_jam':
        return Icons.traffic_rounded;
      case 'map_error':
        return Icons.wrong_location_rounded;
      default:
        return Icons.report_problem_rounded;
    }
  }

  /// Couleur visuelle distinctive pour la cartographie
  Color get color {
    switch (typeIncident) {
      case 'road_closed':
        return const Color(0xFFDC2626); // Rouge vif
      case 'flooding':
        return const Color(0xFF0284C7); // Bleu eau
      case 'accident':
        return const Color(0xFFB91C1C); // Rouge foncé
      case 'pothole':
        return const Color(0xFFEA580C); // Orange danger
      case 'traffic_jam':
        return const Color(0xFFD97706); // Ambre embouteillage
      case 'map_error':
        return const Color(0xFF6B7280); // Gris
      default:
        return const Color(0xFFDC2626);
    }
  }

  /// Couleur de fond avec opacité pour les conteneurs et badges
  Color get lightColor {
    return color.withValues(alpha: 0.12);
  }

  @override
  List<Object?> get props => [
        typeIncident,
        label,
        description,
        defaultDurationHours,
      ];
}
