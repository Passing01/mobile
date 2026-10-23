import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// Modèle représentant un signalement collaboratif actif ou archivé
class ReportModel extends Equatable {
  final int id;
  final String typeIncident;
  final String? description;
  final double latitude;
  final double longitude;
  final String? adresse;
  final String? quartier;
  final String ville;
  final String statut;
  final int scoreConfiance;
  final int upvotes;
  final int downvotes;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final bool isActive;
  final int? userVote; // 1 (upvote), -1 (downvote), null (non voté)

  const ReportModel({
    required this.id,
    required this.typeIncident,
    this.description,
    required this.latitude,
    required this.longitude,
    this.adresse,
    this.quartier,
    this.ville = 'Ouagadougou',
    this.statut = 'active',
    this.scoreConfiance = 1,
    this.upvotes = 1,
    this.downvotes = 0,
    required this.createdAt,
    this.expiresAt,
    this.isActive = true,
    this.userVote,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as int? ?? 0,
      typeIncident: json['type_incident'] as String? ?? 'unknown',
      description: json['description'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      adresse: json['adresse'] as String?,
      quartier: json['quartier'] as String?,
      ville: json['ville'] as String? ?? 'Ouagadougou',
      statut: json['statut'] as String? ?? 'active',
      scoreConfiance: json['score_confiance'] as int? ?? 1,
      upvotes: json['upvotes'] as int? ?? 1,
      downvotes: json['downvotes'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
      expiresAt: json['expires_at'] != null
          ? DateTime.tryParse(json['expires_at'] as String)
          : null,
      isActive: json['is_active'] as bool? ?? true,
      userVote: json['user_vote'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type_incident': typeIncident,
      'description': description,
      'latitude': latitude,
      'longitude': longitude,
      'adresse': adresse,
      'quartier': quartier,
      'ville': ville,
      'statut': statut,
      'score_confiance': scoreConfiance,
      'upvotes': upvotes,
      'downvotes': downvotes,
      'created_at': createdAt.toIso8601String(),
      'expires_at': expiresAt?.toIso8601String(),
      'is_active': isActive,
      'user_vote': userVote,
    };
  }

  ReportModel copyWith({
    int? id,
    String? typeIncident,
    String? description,
    double? latitude,
    double? longitude,
    String? adresse,
    String? quartier,
    String? ville,
    String? statut,
    int? scoreConfiance,
    int? upvotes,
    int? downvotes,
    DateTime? createdAt,
    DateTime? expiresAt,
    bool? isActive,
    int? userVote,
  }) {
    return ReportModel(
      id: id ?? this.id,
      typeIncident: typeIncident ?? this.typeIncident,
      description: description ?? this.description,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      adresse: adresse ?? this.adresse,
      quartier: quartier ?? this.quartier,
      ville: ville ?? this.ville,
      statut: statut ?? this.statut,
      scoreConfiance: scoreConfiance ?? this.scoreConfiance,
      upvotes: upvotes ?? this.upvotes,
      downvotes: downvotes ?? this.downvotes,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      isActive: isActive ?? this.isActive,
      userVote: userVote ?? this.userVote,
    );
  }

  /// Titre lisible adapté aux conducteurs
  String get label {
    switch (typeIncident) {
      case 'road_closed':
        return 'Voie barrée / coupée';
      case 'flooding':
        return 'Inondation / Caniveau';
      case 'accident':
        return 'Accident sur la voie';
      case 'pothole':
        return 'Nid-de-poule dangereux';
      case 'traffic_jam':
        return 'Embouteillage dense';
      case 'map_error':
        return 'Erreur cartographique';
      default:
        return 'Incident routier';
    }
  }

  /// Icône Material du signalement
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

  /// Couleur visuelle d'accentuation
  Color get color {
    switch (typeIncident) {
      case 'road_closed':
        return const Color(0xFFDC2626); // Rouge
      case 'flooding':
        return const Color(0xFF0284C7); // Bleu ciel
      case 'accident':
        return const Color(0xFFB91C1C); // Rouge sombre
      case 'pothole':
        return const Color(0xFFEA580C); // Orange vif
      case 'traffic_jam':
        return const Color(0xFFD97706); // Ambre
      case 'map_error':
        return const Color(0xFF6B7280); // Gris
      default:
        return const Color(0xFFDC2626);
    }
  }

  /// Temps écoulé depuis la création (ex: 'Il y a 12 min')
  String get timeAgo {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'À l\'instant';
    } else if (difference.inMinutes < 60) {
      return 'Il y a ${difference.inMinutes} min';
    } else if (difference.inHours < 24) {
      return 'Il y a ${difference.inHours} h';
    } else {
      return 'Il y a ${difference.inDays} j';
    }
  }

  /// Indique si l'utilisateur courant a voté +1
  bool get hasUserUpvoted => userVote == 1;

  /// Indique si l'utilisateur courant a voté -1
  bool get hasUserDownvoted => userVote == -1;

  @override
  List<Object?> get props => [
        id,
        typeIncident,
        description,
        latitude,
        longitude,
        adresse,
        quartier,
        ville,
        statut,
        scoreConfiance,
        upvotes,
        downvotes,
        createdAt,
        expiresAt,
        isActive,
        userVote,
      ];
}
