import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

/// Repository pour interagir avec les endpoints de calcul d'itinéraires réels
class RoutesRepository {
  final ApiClient apiClient;

  RoutesRepository({required this.apiClient});

  /// Récupère les modes de transport disponibles (Moto, Auto, Vélo, Piéton)
  Future<List<TransportModeInfoModel>> getTransportModes() async {
    try {
      final response = await apiClient.get<dynamic>(ApiEndpoints.routeModes);
      final list = response.data as List<dynamic>;
      return list
          .map((m) => TransportModeInfoModel.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.e('Erreur lors du chargement des modes de transport: $e');
      rethrow;
    }
  }

  String _normalizeMode(String mode) {
    switch (mode.toLowerCase().trim()) {
      case 'motorcycle':
      case 'moto':
      case 'deux-roues':
      case 'deux_roues':
        return 'motorcycle';
      case 'auto':
      case 'car':
      case 'voiture':
      case 'taxi':
        return 'auto';
      case 'bicycle':
      case 'velo':
      case 'vélo':
      case 'bike':
        return 'bicycle';
      case 'pedestrian':
      case 'pieton':
      case 'piéton':
      case 'marche':
      case 'walk':
        return 'pedestrian';
      default:
        return 'motorcycle';
    }
  }

  /// Calcule l'itinéraire optimal entre deux points géographiques réels
  Future<RouteModel> calculateRoute({
    required CoordinateModel origin,
    required CoordinateModel destination,
    String mode = 'motorcycle',
  }) async {
    final normalizedMode = _normalizeMode(mode);

    // Si le départ et l'arrivée sont au même endroit (évite le 422 FastAPI)
    if ((origin.lat - destination.lat).abs() < 0.00005 &&
        (origin.lon - destination.lon).abs() < 0.00005) {
      return RouteModel(
        mode: normalizedMode,
        distanceMeters: 0.0,
        durationSeconds: 0,
        durationFormatted: '0 min',
        geometry: [
          [origin.lat, origin.lon],
          [destination.lat, destination.lon],
        ],
        boundingBox: [
          origin.lat,
          origin.lon,
          destination.lat,
          destination.lon,
        ],
        maneuvers: [
          ManeuverModel(
            order: 1,
            instruction: 'Vous êtes déjà à destination : ${destination.name ?? "Arrivée"}',
            streetName: 'Destination immédiate',
            maneuverType: 'arrive',
            distanceMeters: 0.0,
            durationSeconds: 0,
            location: destination,
          ),
        ],
        engine: 'immediate_arrival',
      );
    }

    try {
      final response = await apiClient.post<dynamic>(
        ApiEndpoints.routeCalculate,
        data: {
          'origin': origin.toJson(),
          'destination': destination.toJson(),
          'mode': normalizedMode,
        },
      ).timeout(const Duration(seconds: 8));
      return RouteModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      AppLogger.w('Serveur de calcul d\'itinéraire indisponible ($e). Activation du mode géodésique de secours.');
      return _buildOfflineFallbackRoute(origin, destination, normalizedMode);
    }
  }

  /// Génère un itinéraire géodésique interpolé en cas de perte réseau ou délai d'expiration serveur
  RouteModel _buildOfflineFallbackRoute(
    CoordinateModel origin,
    CoordinateModel destination,
    String mode,
  ) {
    // Calcul de la distance géodésique (Haversine simplifié)
    const earthRadiusMeters = 6371000.0;
    final dLat = (destination.lat - origin.lat) * 3.141592653589793 / 180.0;
    final dLon = (destination.lon - origin.lon) * 3.141592653589793 / 180.0;

    final distMeters = (earthRadiusMeters * (dLat.abs() + dLon.abs()) * 0.8).clamp(200.0, 50000.0);

    // Vitesse moyenne par mode
    final speedKmh = mode == 'motorcycle'
        ? 35.0
        : mode == 'auto'
            ? 30.0
            : mode == 'bicycle'
                ? 15.0
                : 5.0;

    final durationSeconds = ((distMeters / (speedKmh * 1000 / 3600))).round().clamp(60, 7200);
    final durationMin = (durationSeconds / 60).round().clamp(1, 120);

    // Géométrie interpolée en 5 points
    final geometry = <List<double>>[];
    for (int i = 0; i <= 4; i++) {
      final ratio = i / 4.0;
      final lat = origin.lat + (destination.lat - origin.lat) * ratio;
      final lon = origin.lon + (destination.lon - origin.lon) * ratio;
      geometry.add([lat, lon]);
    }

    final minLat = origin.lat < destination.lat ? origin.lat : destination.lat;
    final maxLat = origin.lat > destination.lat ? origin.lat : destination.lat;
    final minLon = origin.lon < destination.lon ? origin.lon : destination.lon;
    final maxLon = origin.lon > destination.lon ? origin.lon : destination.lon;

    final maneuvers = [
      ManeuverModel(
        order: 1,
        instruction: 'Prenez la route en direction de ${destination.name ?? "votre destination"}',
        streetName: 'Voie principale',
        maneuverType: 'depart',
        distanceMeters: distMeters * 0.4,
        durationSeconds: (durationSeconds * 0.4).round(),
        location: origin,
      ),
      ManeuverModel(
        order: 2,
        instruction: 'Continuez tout droit sur l\'axe urbain',
        streetName: 'Axe principal',
        maneuverType: 'straight',
        distanceMeters: distMeters * 0.5,
        durationSeconds: (durationSeconds * 0.5).round(),
        location: CoordinateModel(
          lat: (origin.lat + destination.lat) / 2,
          lon: (origin.lon + destination.lon) / 2,
        ),
      ),
      ManeuverModel(
        order: 3,
        instruction: 'Vous êtes arrivé à ${destination.name ?? "destination"}',
        streetName: 'Arrivée',
        maneuverType: 'arrive',
        distanceMeters: distMeters * 0.1,
        durationSeconds: (durationSeconds * 0.1).round(),
        location: destination,
      ),
    ];

    return RouteModel(
      mode: mode,
      distanceMeters: distMeters,
      durationSeconds: durationSeconds,
      durationFormatted: '$durationMin min',
      geometry: geometry,
      boundingBox: [minLat, minLon, maxLat, maxLon],
      maneuvers: maneuvers,
      engine: 'geodesic_offline',
    );
  }
}
