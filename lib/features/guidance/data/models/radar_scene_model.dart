import 'dart:math' as math;

/// Monument ou échangeur 3D géolocalisé pour le rendu Faso 3D et la Vue Radar Live
class RadarMonumentItem {
  final String id;
  final String name;
  final String city;
  final String kind;
  final double latitude;
  final double longitude;
  final double heightM;
  final double baseM;
  final String color;
  final double distanceM;
  final double bearingDeg;

  const RadarMonumentItem({
    required this.id,
    required this.name,
    required this.city,
    required this.kind,
    required this.latitude,
    required this.longitude,
    required this.heightM,
    this.baseM = 0.0,
    this.color = '#D97706',
    required this.distanceM,
    required this.bearingDeg,
  });

  factory RadarMonumentItem.fromJson(Map<String, dynamic> json) {
    return RadarMonumentItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? 'Monument',
      city: json['city']?.toString() ?? 'Ouagadougou',
      kind: json['kind']?.toString() ?? 'monument',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      heightM: (json['height_m'] as num?)?.toDouble() ?? 20.0,
      baseM: (json['base_m'] as num?)?.toDouble() ?? 0.0,
      color: json['color']?.toString() ?? '#D97706',
      distanceM: (json['distance_m'] as num?)?.toDouble() ?? 0.0,
      bearingDeg: (json['bearing_deg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Élément routier détecté par le radar (feu tricolore, échangeur, ralentisseur, rond-point...)
class RadarRoadFeatureItem {
  final String id;
  final String kind;
  final String name;
  final double latitude;
  final double longitude;
  final int importance;
  final double distanceM;
  final double bearingDeg;

  const RadarRoadFeatureItem({
    required this.id,
    required this.kind,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.importance = 3,
    required this.distanceM,
    required this.bearingDeg,
  });

  factory RadarRoadFeatureItem.fromJson(Map<String, dynamic> json) {
    return RadarRoadFeatureItem(
      id: json['id']?.toString() ?? '',
      kind: json['kind']?.toString() ?? 'traffic_signal',
      name: json['name']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      importance: (json['importance'] as num?)?.toInt() ?? 3,
      distanceM: (json['distance_m'] as num?)?.toDouble() ?? 0.0,
      bearingDeg: (json['bearing_deg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Repère local multilingue visible sur le radar
class RadarLandmarkItem {
  final String id;
  final String name;
  final String? nameMoore;
  final String? nameDioula;
  final String kind;
  final double latitude;
  final double longitude;
  final int importance;
  final double distanceM;
  final double bearingDeg;

  const RadarLandmarkItem({
    required this.id,
    required this.name,
    this.nameMoore,
    this.nameDioula,
    required this.kind,
    required this.latitude,
    required this.longitude,
    this.importance = 3,
    required this.distanceM,
    required this.bearingDeg,
  });

  factory RadarLandmarkItem.fromJson(Map<String, dynamic> json) {
    return RadarLandmarkItem(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      nameMoore: json['name_moore']?.toString(),
      nameDioula: json['name_dioula']?.toString(),
      kind: json['kind']?.toString() ?? 'monument',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      importance: (json['importance'] as num?)?.toInt() ?? 3,
      distanceM: (json['distance_m'] as num?)?.toDouble() ?? 0.0,
      bearingDeg: (json['bearing_deg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Segment de trafic temps réel capté par le radar
class RadarTrafficItem {
  final String segmentId;
  final double latitude;
  final double longitude;
  final double averageSpeedKmh;
  final String congestionLevel;
  final int samplesCount;
  final double distanceM;
  final double bearingDeg;

  const RadarTrafficItem({
    required this.segmentId,
    required this.latitude,
    required this.longitude,
    required this.averageSpeedKmh,
    required this.congestionLevel,
    required this.samplesCount,
    required this.distanceM,
    required this.bearingDeg,
  });

  factory RadarTrafficItem.fromJson(Map<String, dynamic> json) {
    return RadarTrafficItem(
      segmentId: json['segment_id']?.toString() ?? '',
      latitude: (json['latitude'] as num?)?.toDouble() ?? 0.0,
      longitude: (json['longitude'] as num?)?.toDouble() ?? 0.0,
      averageSpeedKmh: (json['average_speed_kmh'] as num?)?.toDouble() ?? 30.0,
      congestionLevel: json['congestion_level']?.toString() ?? 'fluid',
      samplesCount: (json['samples_count'] as num?)?.toInt() ?? 1,
      distanceM: (json['distance_m'] as num?)?.toDouble() ?? 0.0,
      bearingDeg: (json['bearing_deg'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

/// Scène agrégée autour du conducteur pour la Vue Radar Live et la carte Faso 3D
class RadarSceneModel {
  final double centerLat;
  final double centerLon;
  final double radiusM;
  final List<RadarMonumentItem> monuments3d;
  final List<RadarRoadFeatureItem> roadFeatures;
  final List<RadarLandmarkItem> landmarks;
  final List<RadarTrafficItem> trafficSegments;

  const RadarSceneModel({
    required this.centerLat,
    required this.centerLon,
    required this.radiusM,
    this.monuments3d = const [],
    this.roadFeatures = const [],
    this.landmarks = const [],
    this.trafficSegments = const [],
  });

  factory RadarSceneModel.fromJson(Map<String, dynamic> json) {
    final center = json['center'] as Map<String, dynamic>? ?? const {};
    return RadarSceneModel(
      centerLat: (center['latitude'] as num?)?.toDouble() ?? 12.3685,
      centerLon: (center['longitude'] as num?)?.toDouble() ?? -1.5271,
      radiusM: (json['radius_m'] as num?)?.toDouble() ?? 600.0,
      monuments3d: (json['monuments_3d'] as List<dynamic>? ?? const [])
          .map((e) => RadarMonumentItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      roadFeatures: (json['road_features'] as List<dynamic>? ?? const [])
          .map((e) => RadarRoadFeatureItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      landmarks: (json['landmarks'] as List<dynamic>? ?? const [])
          .map((e) => RadarLandmarkItem.fromJson(e as Map<String, dynamic>))
          .toList(),
      trafficSegments: (json['traffic_segments'] as List<dynamic>? ?? const [])
          .map((e) => RadarTrafficItem.fromJson(e as Map<String, dynamic>))
          .toList(),
    );
  }

  /// Construit un GeoJSON local de repli pour afficher les monuments & échangeurs 3D
  /// du Burkina Faso avec coordonnées exactes OSM et ancrage strict au sol (min_height: 0.0).
  static Map<String, dynamic> buildFallbackMonumentsGeoJson() {
    const specs = <Map<String, dynamic>>[
      {'id': 'ouaga_monument_martyrs', 'name': 'Monument aux Héros Nationaux', 'lat': 12.312187, 'lon': -1.502617, 'h': 55.0, 'base': 0.0, 'r': 11.0, 'color': '#D97706'},
      {'id': 'ouaga_place_nation', 'name': 'Place de la Nation (Flambeau)', 'lat': 12.369752, 'lon': -1.529488, 'h': 22.0, 'base': 0.0, 'r': 12.0, 'color': '#C2410C'},
      {'id': 'ouaga_memorial_sankara', 'name': 'Mémorial Thomas Sankara', 'lat': 12.376886, 'lon': -1.507897, 'h': 34.0, 'base': 0.0, 'r': 18.0, 'color': '#B45309'},
      {'id': 'ouaga_echangeur_nord', 'name': 'Échangeur du Nord', 'lat': 12.384738, 'lon': -1.554870, 'h': 11.0, 'base': 0.0, 'r': 18.0, 'color': '#64748B'},
      {'id': 'ouaga_echangeur_ouest', 'name': 'Échangeur de l\'Ouest', 'lat': 12.351148, 'lon': -1.556825, 'h': 11.0, 'base': 0.0, 'r': 18.0, 'color': '#64748B'},
      {'id': 'ouaga_echangeur_sud', 'name': 'Échangeur du Sud (Ouaga 2000)', 'lat': 12.332088, 'lon': -1.502560, 'h': 11.0, 'base': 0.0, 'r': 18.0, 'color': '#64748B'},
      {'id': 'ouaga_echangeur_yalgado', 'name': 'Échangeur de Yalgado', 'lat': 12.385550, 'lon': -1.502519, 'h': 11.0, 'base': 0.0, 'r': 18.0, 'color': '#64748B'},
      {'id': 'ouaga_echangeur_est', 'name': 'Échangeur de l\'Est', 'lat': 12.361500, 'lon': -1.485500, 'h': 11.0, 'base': 0.0, 'r': 18.0, 'color': '#64748B'},
      {'id': 'ouaga_grande_mosquee', 'name': 'Grande Mosquée de Ouagadougou', 'lat': 12.366216, 'lon': -1.521389, 'h': 30.0, 'base': 0.0, 'r': 18.0, 'color': '#059669'},
      {'id': 'ouaga_cathedrale', 'name': 'Cathédrale de l\'Immaculée-Conception', 'lat': 12.361966, 'lon': -1.526855, 'h': 32.0, 'base': 0.0, 'r': 22.0, 'color': '#D97706'},
      {'id': 'ouaga_palais_sports', 'name': 'Palais des Sports de Ouaga 2000', 'lat': 12.315590, 'lon': -1.498621, 'h': 26.0, 'base': 0.0, 'r': 34.0, 'color': '#2563EB'},
      {'id': 'ouaga_stade_4_aout', 'name': 'Stade du 4-Août', 'lat': 12.367765, 'lon': -1.553511, 'h': 28.0, 'base': 0.0, 'r': 48.0, 'color': '#1D4ED8'},
      {'id': 'bobo_vieille_mosquee', 'name': 'Grande Mosquée de Dioulassoba', 'lat': 11.177802, 'lon': -4.295981, 'h': 20.0, 'base': 0.0, 'r': 16.0, 'color': '#B45309'},
      {'id': 'bobo_cinquantenaire', 'name': 'Rond-point du Cinquantenaire', 'lat': 11.155830, 'lon': -4.284981, 'h': 20.0, 'base': 0.0, 'r': 14.0, 'color': '#D97706'},
    ];

    final features = specs.map((s) {
      final lat = s['lat'] as double;
      final lon = s['lon'] as double;
      final r = s['r'] as double;
      final dLat = r / 111320.0;
      final dLon = r / (111320.0 * math.max(0.2, math.cos(lat * math.pi / 180.0)));
      final ring = <List<double>>[];
      for (var i = 0; i < 12; i++) {
        final a = 2.0 * math.pi * i / 12.0;
        ring.add([lon + dLon * math.cos(a), lat + dLat * math.sin(a)]);
      }
      ring.add(ring.first);

      return {
        'type': 'Feature',
        'id': s['id'],
        'geometry': {
          'type': 'Polygon',
          'coordinates': [ring],
        },
        'properties': {
          'id': s['id'],
          'name': s['name'],
          'height': s['h'],
          'min_height': s['base'],
          'color': s['color'],
        },
      };
    }).toList();

    return {
      'type': 'FeatureCollection',
      'features': features,
    };
  }
}

