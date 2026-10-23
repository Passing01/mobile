import 'package:equatable/equatable.dart';

/// Coordonnée géographique pour le calcul d'itinéraires
class CoordinateModel extends Equatable {
  final double lat;
  final double lon;
  final String? name;

  const CoordinateModel({
    required this.lat,
    required this.lon,
    this.name,
  });

  factory CoordinateModel.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = <String, dynamic>{};
    rawJson.forEach((k, v) => json[k.toString()] = v);
    return CoordinateModel(
      lat: (json['lat'] as num?)?.toDouble() ?? 0.0,
      lon: (json['lon'] as num?)?.toDouble() ?? 0.0,
      name: json['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'lat': lat,
      'lon': lon,
      if (name != null) 'name': name,
    };
  }

  @override
  List<Object?> get props => [lat, lon, name];
}

/// Mode de transport disponible
class TransportModeInfoModel extends Equatable {
  final String mode;
  final String label;
  final String description;
  final double averageSpeedKmh;

  const TransportModeInfoModel({
    required this.mode,
    required this.label,
    required this.description,
    required this.averageSpeedKmh,
  });

  factory TransportModeInfoModel.fromJson(Map<String, dynamic> json) {
    return TransportModeInfoModel(
      mode: json['mode'] as String,
      label: json['label'] as String,
      description: json['description'] as String,
      averageSpeedKmh: (json['average_speed_kmh'] as num).toDouble(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'label': label,
      'description': description,
      'average_speed_kmh': averageSpeedKmh,
    };
  }

  @override
  List<Object?> get props => [mode, label, description, averageSpeedKmh];
}

/// Étape ou manœuvre du guidage pas-à-pas
class ManeuverModel extends Equatable {
  final int order;
  final String instruction;
  final String? streetName;
  final String maneuverType;
  final double distanceMeters;
  final int durationSeconds;
  final CoordinateModel location;

  const ManeuverModel({
    required this.order,
    required this.instruction,
    this.streetName,
    required this.maneuverType,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.location,
  });

  factory ManeuverModel.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = <String, dynamic>{};
    rawJson.forEach((k, v) => json[k.toString()] = v);
    final rawLoc = json['location'];
    final locMap = rawLoc is Map ? rawLoc : <String, dynamic>{};

    return ManeuverModel(
      order: (json['order'] as num?)?.toInt() ?? 1,
      instruction: json['instruction']?.toString() ?? 'Continuer',
      streetName: json['street_name'] as String?,
      maneuverType: json['maneuver_type'] as String? ?? 'straight',
      distanceMeters: (json['distance_meters'] as num?)?.toDouble() ?? 0.0,
      durationSeconds: (json['duration_seconds'] as num?)?.toInt() ?? 0,
      location: CoordinateModel.fromJson(locMap),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order': order,
      'instruction': instruction,
      if (streetName != null) 'street_name': streetName,
      'maneuver_type': maneuverType,
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      'location': location.toJson(),
    };
  }

  @override
  List<Object?> get props => [
        order,
        instruction,
        streetName,
        maneuverType,
        distanceMeters,
        durationSeconds,
        location,
      ];
}

/// Résultat complet du calcul d'itinéraire optimal retourné par le backend
class RouteModel extends Equatable {
  final String mode;
  final double distanceMeters;
  final int durationSeconds;
  final String durationFormatted;
  final List<List<double>> geometry;
  final List<double> boundingBox;
  final List<ManeuverModel> maneuvers;
  final String engine;

  const RouteModel({
    required this.mode,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.durationFormatted,
    required this.geometry,
    required this.boundingBox,
    required this.maneuvers,
    required this.engine,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final rawGeo = json['geometry'];
    final parsedGeo = <List<double>>[];
    if (rawGeo is List) {
      for (final point in rawGeo) {
        if (point is List && point.length >= 2) {
          final lat = (point[0] as num).toDouble();
          final lon = (point[1] as num).toDouble();
          if (lat.isFinite && lon.isFinite) {
            parsedGeo.add([lat, lon]);
          }
        }
      }
    }

    final rawBox = json['bounding_box'];
    final parsedBox = <double>[];
    if (rawBox is List) {
      for (final b in rawBox) {
        if (b is num && b.toDouble().isFinite) {
          parsedBox.add(b.toDouble());
        }
      }
    }
    if (parsedBox.length < 4 && parsedGeo.isNotEmpty) {
      double minLat = parsedGeo.first[0];
      double maxLat = parsedGeo.first[0];
      double minLon = parsedGeo.first[1];
      double maxLon = parsedGeo.first[1];
      for (final pt in parsedGeo) {
        if (pt[0] < minLat) minLat = pt[0];
        if (pt[0] > maxLat) maxLat = pt[0];
        if (pt[1] < minLon) minLon = pt[1];
        if (pt[1] > maxLon) maxLon = pt[1];
      }
      parsedBox..clear()..addAll([minLat, minLon, maxLat, maxLon]);
    }

    final rawManeuvers = json['maneuvers'];
    final parsedManeuvers = <ManeuverModel>[];
    if (rawManeuvers is List) {
      for (final m in rawManeuvers) {
        if (m is Map) {
          try {
            parsedManeuvers.add(ManeuverModel.fromJson(m));
          } catch (_) {}
        }
      }
    }

    final dist = ((json['distance_meters'] ?? 0.0) as num).toDouble();
    final dur = ((json['duration_seconds'] ?? 0) as num).toInt();
    final durFormatted = (json['duration_formatted'] as String?) ??
        '${(dur / 60).round().clamp(1, 180)} min';

    return RouteModel(
      mode: (json['mode'] as String?) ?? 'motorcycle',
      distanceMeters: dist,
      durationSeconds: dur,
      durationFormatted: durFormatted,
      geometry: parsedGeo,
      boundingBox: parsedBox.length >= 4
          ? parsedBox
          : const [12.35, -1.55, 12.38, -1.50],
      maneuvers: parsedManeuvers,
      engine: (json['engine'] as String?) ?? 'valhalla',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      'duration_formatted': durationFormatted,
      'geometry': geometry,
      'bounding_box': boundingBox,
      'maneuvers': maneuvers.map((m) => m.toJson()).toList(),
      'engine': engine,
    };
  }

  /// Distance formatée (ex: "840 m" ou "7.2 km")
  String get distanceFormatted {
    if (distanceMeters < 1000) {
      return '${distanceMeters.round()} m';
    }
    return '${(distanceMeters / 1000).toStringAsFixed(1)} km';
  }

  @override
  List<Object?> get props => [
        mode,
        distanceMeters,
        durationSeconds,
        durationFormatted,
        geometry,
        boundingBox,
        maneuvers,
        engine,
      ];
}
