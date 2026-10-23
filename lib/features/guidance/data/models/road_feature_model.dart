import 'package:equatable/equatable.dart';

/// Type d'élément routier servant d'ancre pour le guidage
enum RoadFeatureKind {
  trafficSignal('traffic_signal', 'Feu tricolore'),
  interchange('interchange', 'Échangeur'),
  bridge('bridge', 'Pont'),
  roundabout('roundabout', 'Rond-point'),
  levelCrossing('level_crossing', 'Passage à niveau'),
  speedBump('speed_bump', 'Ralentisseur / Dos d\'âne'),
  toll('toll', 'Péage'),
  checkpoint('checkpoint', 'Poste de contrôle');

  final String slug;
  final String label;
  const RoadFeatureKind(this.slug, this.label);

  static RoadFeatureKind fromString(String raw) {
    for (final val in RoadFeatureKind.values) {
      if (val.slug == raw || val.name == raw) return val;
    }
    return RoadFeatureKind.trafficSignal;
  }
}

/// Modèle d'élément routier stocké dans road_features (feux, ponts, échangeurs)
class RoadFeatureModel extends Equatable {
  final String id;
  final RoadFeatureKind kind;
  final String? name;
  final double latitude;
  final double longitude;
  final int? osmWayId;
  final Map<String, dynamic> attrs;
  final int importance;
  final String status;
  final String source;
  final int confidence;

  const RoadFeatureModel({
    required this.id,
    required this.kind,
    this.name,
    required this.latitude,
    required this.longitude,
    this.osmWayId,
    this.attrs = const {},
    this.importance = 3,
    this.status = 'validated',
    this.source = 'admin',
    this.confidence = 2,
  });

  bool get isTrafficSignal => kind == RoadFeatureKind.trafficSignal;

  factory RoadFeatureModel.fromJson(Map<String, dynamic> json) {
    double lat = 0.0;
    double lon = 0.0;
    if (json.containsKey('latitude') && json.containsKey('longitude')) {
      lat = (json['latitude'] as num).toDouble();
      lon = (json['longitude'] as num).toDouble();
    } else if (json['geom'] is Map) {
      final geom = json['geom'] as Map<String, dynamic>;
      final coords = geom['coordinates'] as List<dynamic>?;
      if (coords != null && coords.length >= 2) {
        lon = (coords[0] as num).toDouble();
        lat = (coords[1] as num).toDouble();
      }
    }

    return RoadFeatureModel(
      id: json['id']?.toString() ?? '',
      kind: RoadFeatureKind.fromString(json['kind']?.toString() ?? 'traffic_signal'),
      name: json['name'] as String?,
      latitude: lat,
      longitude: lon,
      osmWayId: (json['osm_way_id'] as num?)?.toInt(),
      attrs: (json['attrs'] as Map<String, dynamic>?) ?? const {},
      importance: (json['importance'] as num?)?.toInt() ?? 3,
      status: (json['status'] as String?) ?? 'validated',
      source: (json['source'] as String?) ?? 'admin',
      confidence: (json['confidence'] as num?)?.toInt() ?? 2,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'kind': kind.slug,
      if (name != null) 'name': name,
      'latitude': latitude,
      'longitude': longitude,
      if (osmWayId != null) 'osm_way_id': osmWayId,
      if (attrs.isNotEmpty) 'attrs': attrs,
      'importance': importance,
      'status': status,
      'source': source,
      'confidence': confidence,
    };
  }

  @override
  List<Object?> get props => [
        id,
        kind,
        name,
        latitude,
        longitude,
        osmWayId,
        attrs,
        importance,
        status,
        source,
        confidence,
      ];
}
