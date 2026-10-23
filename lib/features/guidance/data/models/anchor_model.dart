import 'package:equatable/equatable.dart';

/// Représente une ancre de repérage identifiée le long du corridor de navigation
class AnchorModel extends Equatable {
  final String kind; // 'interchange', 'bridge', 'roundabout', 'traffic_signal', 'landmark', 'place'
  final String id;
  final String? name;
  final double s; // Distance curviligne depuis le départ (mètres)
  final String side; // 'left' | 'right' | 'on'
  final double lateralM; // Distance latérale au tracé (mètres)
  final int importance; // 1 à 5
  final int confidence; // 3 relevé terrain, 2 source ouverte, 1 incertain
  final double? latitude;
  final double? longitude;

  const AnchorModel({
    required this.kind,
    required this.id,
    this.name,
    required this.s,
    this.side = 'on',
    this.lateralM = 0.0,
    this.importance = 3,
    this.confidence = 2,
    this.latitude,
    this.longitude,
  });

  factory AnchorModel.fromJson(Map<String, dynamic> json) {
    return AnchorModel(
      kind: json['kind'] as String? ?? 'place',
      id: json['id']?.toString() ?? '',
      name: json['name'] as String?,
      s: (json['s'] as num?)?.toDouble() ?? 0.0,
      side: json['side'] as String? ?? 'on',
      lateralM: (json['lateral_m'] as num?)?.toDouble() ?? 0.0,
      importance: (json['importance'] as num?)?.toInt() ?? 3,
      confidence: (json['confidence'] as num?)?.toInt() ?? 2,
      latitude: (json['lat'] as num?)?.toDouble() ?? (json['latitude'] as num?)?.toDouble(),
      longitude: (json['lng'] as num?)?.toDouble() ?? (json['longitude'] as num?)?.toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kind': kind,
      'id': id,
      if (name != null) 'name': name,
      's': s,
      'side': side,
      'lateral_m': lateralM,
      'importance': importance,
      'confidence': confidence,
      if (latitude != null) 'lat': latitude,
      if (longitude != null) 'lng': longitude,
    };
  }

  /// Nom d'affichage par défaut si aucun nom n'est spécifié
  String get displayName {
    if (name != null && name!.trim().isNotEmpty) {
      return name!;
    }
    switch (kind) {
      case 'traffic_signal':
        return 'le feu tricolore';
      case 'bridge':
        return 'le pont';
      case 'interchange':
        return 'l\'échangeur';
      case 'roundabout':
        return 'le rond-point';
      case 'landmark':
        return 'le repère';
      default:
        return 'le repère';
    }
  }

  @override
  List<Object?> get props => [
        kind,
        id,
        name,
        s,
        side,
        lateralM,
        importance,
        confidence,
        latitude,
        longitude,
      ];
}
