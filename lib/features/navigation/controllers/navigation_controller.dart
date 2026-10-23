import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart' as geo;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:turf/turf.dart' as turf;
import 'package:qvgestion_mobile/core/services/route_service.dart';
import 'package:qvgestion_mobile/core/services/voice_guide_service.dart';
import 'package:qvgestion_mobile/core/services/traffic_telemetry_service.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';

/// Trace l'itinéraire calculé sur le canvas vectoriel Mapbox sans crash NDK
Future<void> drawRoute(mb.MapboxMap map, Map<String, dynamic> geometry) async {
  try {
    final manager = await map.annotations.createPolylineAnnotationManager(id: 'route_polyline_mgr');
    await manager.deleteAll();
    final rawCoords = geometry['coordinates'] as List<dynamic>?;
    if (rawCoords != null && rawCoords.isNotEmpty) {
      final positions = rawCoords.map((c) {
        final list = c as List<dynamic>;
        return turf.Position((list[0] as num).toDouble(), (list[1] as num).toDouble());
      }).toList();
      await manager.create(
        mb.PolylineAnnotationOptions(
          geometry: turf.LineString(coordinates: positions),
          lineColor: 0xFF2563EB,
          lineWidth: 6.5,
          lineJoin: mb.LineJoin.ROUND,
        ),
      );
    }
  } catch (e) {
    AppLogger.w('Tracé sécurisé Mapbox: $e');
  }
}

/// Contrôleur de guidage temps réel conforme au guide technique QvGestion :
/// - Suivi GPS haute précision
/// - Projection de la position sur la ligne via Turf
/// - Détection de déviation (40m, 3 fixes consécutifs, cooldown 10s)
/// - Annonces vocales par seuils (200m et 50m) et repères locaux
/// - Suivi de caméra dynamique avec cap et inclinaison
/// - Télémétrie trafic en continu
class NavigationController {
  NavigationController({
    required this.map,
    required this.routes,
    required this.voice,
    this.telemetry,
    this.onRouteUpdated,
    this.onArrival,
  });

  final mb.MapboxMap map;
  final RouteService routes;
  final VoiceGuide voice;
  final TrafficTelemetryService? telemetry;
  final void Function(Map<String, dynamic> routeData)? onRouteUpdated;
  final VoidCallback? onArrival;

  static const offRouteMeters = 40.0; // Seuil de déviation en mètres
  static const offRouteFixes = 3; // Positions consécutives hors route
  static const rerouteCooldown = Duration(seconds: 10);

  late List<List<double>> _waypoints; // [[lng, lat], ...]
  late turf.LineString _line;
  List<dynamic> _steps = [];
  int _stepIndex = 0;
  int _offRoute = 0;
  bool _rerouting = false;
  bool _isNavigating = false;
  DateTime _lastReroute = DateTime.fromMillisecondsSinceEpoch(0);
  final Set<String> _spoken = {};
  StreamSubscription<geo.Position>? _sub;

  bool get isNavigating => _isNavigating;
  int get stepIndex => _stepIndex;
  List<dynamic> get steps => _steps;

  /// Lance la navigation active à partir d'une position de départ
  Future<void> start(geo.Position from, List<List<double>> waypoints) async {
    _isNavigating = true;
    _waypoints = List.of(waypoints);
    await _loadRoute(from);

    _sub = geo.Geolocator.getPositionStream(
      locationSettings: const geo.LocationSettings(
        accuracy: geo.LocationAccuracy.bestForNavigation,
        distanceFilter: 5,
      ),
    ).listen(_onPosition);
  }

  /// Arrête la navigation et libère les écouteurs
  Future<void> stop() async {
    _isNavigating = false;
    await _sub?.cancel();
    _sub = null;
    await voice.stop();
  }

  Future<void> _loadRoute(geo.Position from) async {
    final points = [
      [from.longitude, from.latitude],
      ..._waypoints,
    ];

    final data = await routes.computeRaw(points);
    final rawCoords = data['geometry']['coordinates'] as List;
    final coords = rawCoords
        .map((c) => turf.Position(c[0] as num, c[1] as num))
        .toList();

    _line = turf.LineString(coordinates: coords);
    _steps = data['steps'] as List? ?? [];
    _stepIndex = 0;
    _spoken.clear();

    await drawRoute(map, data['geometry'] as Map<String, dynamic>);
    onRouteUpdated?.call(data);
  }

  Future<void> _onPosition(geo.Position p) async {
    if (!_isNavigating) return;

    // Émet la position pour la télémétrie trafic temps réel
    telemetry?.sendPosition(p);

    // 1. Distance à l'itinéraire en mètres via Turf
    final snapped = turf.nearestPointOnLine(
      _line,
      turf.Point(coordinates: turf.Position(p.longitude, p.latitude)),
      turf.Unit.meters,
    );
    final dist = snapped.properties!['dist'] as num;

    // 2. Déviation : plusieurs positions de suite, avec délai entre deux recalculs
    _offRoute = dist > offRouteMeters ? _offRoute + 1 : 0;
    final canReroute = DateTime.now().difference(_lastReroute) > rerouteCooldown;

    if (_offRoute >= offRouteFixes && !_rerouting && canReroute) {
      _rerouting = true;
      try {
        await voice.say('Recalcul de l\'itinéraire');
        await _loadRoute(p);
        _offRoute = 0;
      } catch (_) {
        // En cas de perte réseau temporaire, on conserve l'ancien tracé
      } finally {
        _lastReroute = DateTime.now();
        _rerouting = false;
      }
      return;
    }

    // 3. Prochaine manœuvre (annonces aux seuils de 200m et 50m)
    await _announce(p);

    // 4. Caméra fluide qui suit le déplacement
    try {
      await map.easeTo(
        mb.CameraOptions(
          center: mb.Point(coordinates: mb.Position(p.longitude, p.latitude)),
          bearing: p.speed > 1 ? p.heading : null, // Cap fiable en mouvement
          zoom: 17.0,
          pitch: 50.0,
        ),
        mb.MapAnimationOptions(duration: 800),
      );
    } catch (_) {}

    // 5. Arrivée à destination (< 25 mètres)
    if (_waypoints.isNotEmpty) {
      final end = _waypoints.last;
      final left = geo.Geolocator.distanceBetween(
        p.latitude,
        p.longitude,
        end[1],
        end[0],
      );

      if (left < 25) {
        await voice.say('Vous êtes arrivé');
        onArrival?.call();
        await stop();
      }
    }
  }

  Future<void> _announce(geo.Position p) async {
    if (_stepIndex + 1 >= _steps.length) return;
    final next = _steps[_stepIndex + 1];

    if (next is! Map<String, dynamic> || next['maneuver'] is! Map) return;
    final loc = next['maneuver']['location'] as List?;
    if (loc == null || loc.length < 2) return;

    final targetLon = (loc[0] as num).toDouble();
    final targetLat = (loc[1] as num).toDouble();
    final d = geo.Geolocator.distanceBetween(p.latitude, p.longitude, targetLat, targetLon);

    for (final threshold in [200, 50]) {
      final key = '$_stepIndex-$threshold';
      if (d <= threshold && _spoken.add(key)) {
        await voice.sayStep(next);
      }
    }

    if (d < 20) {
      _stepIndex++; // Manœuvre franchie avec succès
    }
  }
}
