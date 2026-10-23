import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'anchor_model.dart';

/// Modèle représentant une manœuvre enrichie avec repères familiers, ancres et niveau de confiance
/// Conforme au Narrateur v2 de FASO NAV
class EnrichedManeuverModel extends Equatable {
  final int order;
  final String originalInstruction;
  final String localizedInstruction;
  final String language;
  final String maneuverType;
  final bool hasLandmark;
  final String? landmarkName;
  final double distanceMeters;
  final int durationSeconds;
  final String? audioSoundId;
  final String? audioUrl;

  // Extensions Narrateur v2
  final int confidence; // 3 relevé terrain, 2 déduit d'une source ouverte, 1 incertain
  final String? templateKey;
  final AnchorModel? anchor;

  const EnrichedManeuverModel({
    required this.order,
    required this.originalInstruction,
    required this.localizedInstruction,
    required this.language,
    required this.maneuverType,
    required this.hasLandmark,
    this.landmarkName,
    required this.distanceMeters,
    required this.durationSeconds,
    this.audioSoundId,
    this.audioUrl,
    this.confidence = 2,
    this.templateKey,
    this.anchor,
  });

  factory EnrichedManeuverModel.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = <String, dynamic>{};
    rawJson.forEach((k, v) => json[k.toString()] = v);

    final rawAnchor = json['anchor'];
    Map<String, dynamic>? anchorMap;
    if (rawAnchor is Map) {
      anchorMap = <String, dynamic>{};
      rawAnchor.forEach((k, v) => anchorMap![k.toString()] = v);
    }

    return EnrichedManeuverModel(
      order: (json['order'] as num?)?.toInt() ?? 1,
      originalInstruction: json['original_instruction'] as String? ?? '',
      localizedInstruction: json['localized_instruction'] as String? ?? '',
      language: json['language'] as String? ?? 'fr',
      maneuverType: json['maneuver_type'] as String? ?? 'straight',
      hasLandmark: (json['has_landmark'] as bool?) ?? (json['landmark_name'] != null),
      landmarkName: json['landmark_name'] as String?,
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      audioSoundId: json['audio_sound_id'] as String?,
      audioUrl: json['audio_url'] as String?,
      confidence: (json['confidence'] as num?)?.toInt() ?? 2,
      templateKey: json['template_key'] as String?,
      anchor: anchorMap != null ? AnchorModel.fromJson(anchorMap) : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order': order,
      'original_instruction': originalInstruction,
      'localized_instruction': localizedInstruction,
      'language': language,
      'maneuver_type': maneuverType,
      'has_landmark': hasLandmark,
      if (landmarkName != null) 'landmark_name': landmarkName,
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      if (audioSoundId != null) 'audio_sound_id': audioSoundId,
      if (audioUrl != null) 'audio_url': audioUrl,
      'confidence': confidence,
      if (templateKey != null) 'template_key': templateKey,
      if (anchor != null) 'anchor': anchor!.toJson(),
    };
  }

  /// Libellé du niveau de confiance
  String get confidenceLabel {
    switch (confidence) {
      case 3:
        return 'Relevé terrain certifié';
      case 2:
        return 'Déduit de données ouvertes';
      case 1:
      default:
        return 'Consigne estimée (non certifiée)';
    }
  }

  /// Couleur associée au niveau de confiance
  Color get confidenceColor {
    switch (confidence) {
      case 3:
        return const Color(0xFF16A34A); // Vert
      case 2:
        return const Color(0xFF2563EB); // Bleu
      case 1:
      default:
        return const Color(0xFFEA580C); // Orange ambré
    }
  }

  /// Icône Material adaptée au virage / action
  IconData get iconData {
    switch (maneuverType) {
      case 'turn_left':
        return Icons.turn_left_rounded;
      case 'turn_right':
        return Icons.turn_right_rounded;
      case 'straight':
        return Icons.straight_rounded;
      case 'roundabout':
        return Icons.roundabout_left_rounded;
      case 'depart':
        return Icons.navigation_rounded;
      case 'arrive':
        return Icons.flag_rounded;
      default:
        return Icons.arrow_forward_rounded;
    }
  }

  /// Format lisible de la distance (ex: 350 m, 1.2 km)
  String get distanceFormatted {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    } else {
      final km = distanceMeters / 1000;
      return '${km.toStringAsFixed(1)} km';
    }
  }

  /// Format lisible de la durée (ex: 2 min, 45 s)
  String get durationFormatted {
    if (durationSeconds < 60) {
      return '$durationSeconds s';
    } else {
      final mins = (durationSeconds / 60).round();
      return '$mins min';
    }
  }

  EnrichedManeuverModel copyWith({
    int? order,
    String? originalInstruction,
    String? localizedInstruction,
    String? language,
    String? maneuverType,
    bool? hasLandmark,
    String? landmarkName,
    double? distanceMeters,
    int? durationSeconds,
    String? audioSoundId,
    String? audioUrl,
    int? confidence,
    String? templateKey,
    AnchorModel? anchor,
  }) {
    return EnrichedManeuverModel(
      order: order ?? this.order,
      originalInstruction: originalInstruction ?? this.originalInstruction,
      localizedInstruction: localizedInstruction ?? this.localizedInstruction,
      language: language ?? this.language,
      maneuverType: maneuverType ?? this.maneuverType,
      hasLandmark: hasLandmark ?? this.hasLandmark,
      landmarkName: landmarkName ?? this.landmarkName,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      audioSoundId: audioSoundId ?? this.audioSoundId,
      audioUrl: audioUrl ?? this.audioUrl,
      confidence: confidence ?? this.confidence,
      templateKey: templateKey ?? this.templateKey,
      anchor: anchor ?? this.anchor,
    );
  }

  @override
  List<Object?> get props => [
        order,
        originalInstruction,
        localizedInstruction,
        language,
        maneuverType,
        hasLandmark,
        landmarkName,
        distanceMeters,
        durationSeconds,
        audioSoundId,
        audioUrl,
        confidence,
        templateKey,
        anchor,
      ];
}
