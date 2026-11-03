import 'package:equatable/equatable.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';

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
  final List<String> streetNames;
  final String maneuverType;
  final double distanceMeters;
  final int durationSeconds;
  final CoordinateModel location;
  final dynamic type;
  final double lat;
  final double lng;
  final double lengthM;
  final double timeS;

  const ManeuverModel({
    required this.order,
    required this.instruction,
    this.streetName,
    this.streetNames = const [],
    required this.maneuverType,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.location,
    this.type,
    this.lat = 0.0,
    this.lng = 0.0,
    this.lengthM = 0.0,
    this.timeS = 0.0,
  });

  factory ManeuverModel.fromJson(Map<dynamic, dynamic> rawJson) {
    final json = <String, dynamic>{};
    rawJson.forEach((k, v) => json[k.toString()] = v);

    final rawLoc = json['location'];
    double lat = 0.0;
    double lon = 0.0;
    if (json.containsKey('lat') && json.containsKey('lng')) {
      lat = (json['lat'] as num?)?.toDouble() ?? 0.0;
      lon = (json['lng'] as num?)?.toDouble() ?? 0.0;
    } else if (rawLoc is Map) {
      lat = (rawLoc['latitude'] ?? rawLoc['lat'] as num?)?.toDouble() ?? 0.0;
      lon = (rawLoc['longitude'] ?? rawLoc['lon'] ?? rawLoc['lng'] as num?)?.toDouble() ?? 0.0;
    }

    final streetNamesList = <String>[];
    if (json['street_names'] is List) {
      for (final s in json['street_names']) {
        if (s != null) streetNamesList.add(s.toString());
      }
    }

    final length = ((json['length_m'] ?? json['distance_meters'] ?? 0.0) as num).toDouble();
    final time = ((json['time_s'] ?? json['duration_seconds'] ?? 0.0) as num).toDouble();
    final streetName = json['street_name']?.toString() ??
        (streetNamesList.isNotEmpty ? streetNamesList.join(', ') : null);

    return ManeuverModel(
      order: (json['order'] as num?)?.toInt() ?? 1,
      instruction: json['instruction']?.toString() ?? 'Continuer',
      streetName: streetName,
      streetNames: streetNamesList,
      maneuverType: json['type']?.toString() ?? json['maneuver_type']?.toString() ?? 'straight',
      distanceMeters: length,
      durationSeconds: time.round(),
      location: CoordinateModel(lat: lat, lon: lon, name: streetName),
      type: json['type'],
      lat: lat,
      lng: lon,
      lengthM: length,
      timeS: time,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'order': order,
      'instruction': instruction,
      if (streetName != null) 'street_name': streetName,
      'street_names': streetNames,
      'maneuver_type': maneuverType,
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      'location': location.toJson(),
      'type': type,
      'lat': lat,
      'lng': lng,
      'length_m': lengthM,
      'time_s': timeS,
    };
  }

  @override
  List<Object?> get props => [
        order,
        instruction,
        streetName,
        streetNames,
        maneuverType,
        distanceMeters,
        durationSeconds,
        location,
        type,
        lat,
        lng,
        lengthM,
        timeS,
      ];
}

/// Résultat complet du calcul d'itinéraire optimal retourné par le backend
class RouteModel extends Equatable {
  final String mode;
  final double distanceMeters;
  final int durationSeconds;
  final String durationFormatted;
  final int legs;
  final List<List<double>> geometry;
  final List<double> boundingBox;
  final List<ManeuverModel> maneuvers;
  final String engine;
  final int? startSnapM;
  final List<List<double>>? walkingSegment;
  final double? walkingDistanceMeters;

  const RouteModel({
    required this.mode,
    required this.distanceMeters,
    required this.durationSeconds,
    required this.durationFormatted,
    this.legs = 1,
    required this.geometry,
    required this.boundingBox,
    required this.maneuvers,
    required this.engine,
    this.startSnapM,
    this.walkingSegment,
    this.walkingDistanceMeters,
  });

  factory RouteModel.fromJson(Map<String, dynamic> json) {
    final rawGeo = json['geometry'];
    final parsedGeo = <List<double>>[];
    if (rawGeo is Map) {
      final coords = rawGeo['coordinates'];
      if (coords is List) {
        for (final point in coords) {
          if (point is List && point.length >= 2) {
            final c0 = (point[0] as num).toDouble();
            final c1 = (point[1] as num).toDouble();
            if (c0.isFinite && c1.isFinite) {
              parsedGeo.add([c0, c1]);
            }
          }
        }
      }
    } else if (rawGeo is List) {
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
      double minLat = 90.0;
      double maxLat = -90.0;
      double minLon = 180.0;
      double maxLon = -180.0;
      for (final pt in parsedGeo) {
        // En GeoJSON [lon, lat]
        final lon = pt[0] < 5.0 ? pt[0] : pt[1];
        final lat = pt[1] > 8.0 ? pt[1] : pt[0];
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lon < minLon) minLon = lon;
        if (lon > maxLon) maxLon = lon;
      }
      parsedBox..clear()..addAll([minLat, minLon, maxLat, maxLon]);
    }

    final rawManeuvers = json['maneuvers'];
    final parsedManeuvers = <ManeuverModel>[];
    if (rawManeuvers is List) {
      for (final m in rawManeuvers) {
        if (m is Map) {
          try {
            parsedManeuvers.add(ManeuverModel.fromJson(Map<String, dynamic>.from(m)));
          } catch (e) {
            AppLogger.w('Format de manœuvre ignoré: $e');
          }
        }
      }
    }

    final modeStr = ((json['mode'] as String?) ?? 'moto').toLowerCase().trim();
    final dist = ((json['distance_m'] ?? json['distance_meters'] ?? 0.0) as num).toDouble();
    final rawDur = ((json['duration_s'] ?? json['duration_seconds'] ?? 0) as num).round();
    int dur = rawDur;
    if (dist > 0) {
      final impliedSpeedMps = dur > 0 ? dist / dur : 999.0;
      if (modeStr == 'pied' || modeStr == 'pieton' || modeStr == 'pedestrian') {
        if (impliedSpeedMps > 2.5) {
          dur = (dist / 1.3333).round();
        }
      } else if (modeStr == 'velo' || modeStr == 'bicycle') {
        if (impliedSpeedMps > 6.5 || impliedSpeedMps < 2.0) {
          dur = (dist / 4.1667).round();
        }
      } else if ((modeStr == 'moto' || modeStr == 'motorcycle') && dist > 15000) {
        if (impliedSpeedMps > 18.0) {
          dur = (dist / 16.11).round();
        }
      }
    }
    final durFormatted = (json['duration_formatted'] as String?) ??
        (dur < 60
            ? '${dur}s'
            : dur < 3600
                ? '${(dur / 60).round()} min'
                : '${dur ~/ 3600} h ${(dur % 3600 ~/ 60)} min');

    final rawWalk = json['walking_segment'];
    List<List<double>>? parsedWalk;
    if (rawWalk is Map && rawWalk['coordinates'] is List) {
      final wcoords = rawWalk['coordinates'] as List;
      final pts = <List<double>>[];
      for (final p in wcoords) {
        if (p is List && p.length >= 2) {
          final c0 = (p[0] as num).toDouble();
          final c1 = (p[1] as num).toDouble();
          if (c0.isFinite && c1.isFinite) {
            pts.add([c0, c1]);
          }
        }
      }
      if (pts.isNotEmpty) parsedWalk = pts;
    }
    final walkingDist = (json['walking_distance_m'] as num?)?.toDouble();

    return RouteModel(
      mode: (json['mode'] as String?) ?? 'moto',
      distanceMeters: dist,
      durationSeconds: dur,
      durationFormatted: durFormatted,
      legs: (json['legs'] as num?)?.toInt() ?? 1,
      geometry: parsedGeo,
      boundingBox: parsedBox.length >= 4
          ? parsedBox
          : const [12.35, -1.55, 12.38, -1.50],
      maneuvers: parsedManeuvers,
      engine: (json['engine'] as String?) ?? 'valhalla',
      startSnapM: (json['start_snap_m'] as num?)?.toInt(),
      walkingSegment: parsedWalk,
      walkingDistanceMeters: walkingDist,
    );
  }

  RouteModel copyWith({
    String? mode,
    double? distanceMeters,
    int? durationSeconds,
    String? durationFormatted,
    int? legs,
    List<List<double>>? geometry,
    List<double>? boundingBox,
    List<ManeuverModel>? maneuvers,
    String? engine,
    int? startSnapM,
    List<List<double>>? walkingSegment,
    double? walkingDistanceMeters,
  }) {
    return RouteModel(
      mode: mode ?? this.mode,
      distanceMeters: distanceMeters ?? this.distanceMeters,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      durationFormatted: durationFormatted ?? this.durationFormatted,
      legs: legs ?? this.legs,
      geometry: geometry ?? this.geometry,
      boundingBox: boundingBox ?? this.boundingBox,
      maneuvers: maneuvers ?? this.maneuvers,
      engine: engine ?? this.engine,
      startSnapM: startSnapM ?? this.startSnapM,
      walkingSegment: walkingSegment ?? this.walkingSegment,
      walkingDistanceMeters: walkingDistanceMeters ?? this.walkingDistanceMeters,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'mode': mode,
      'distance_meters': distanceMeters,
      'duration_seconds': durationSeconds,
      'duration_formatted': durationFormatted,
      'legs': legs,
      'geometry': geometry,
      'bounding_box': boundingBox,
      'maneuvers': maneuvers.map((m) => m.toJson()).toList(),
      'engine': engine,
      if (startSnapM != null) 'start_snap_m': startSnapM,
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
        legs,
        geometry,
        boundingBox,
        maneuvers,
        engine,
        startSnapM,
        walkingSegment,
        walkingDistanceMeters,
      ];
}
