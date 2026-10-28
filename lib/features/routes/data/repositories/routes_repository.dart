import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/services/route_service.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

/// Repository pour interagir avec les endpoints de calcul d'itinéraires réels (Étape 7)
class RoutesRepository {
  final ApiClient apiClient;
  final RouteService routeService;

  RoutesRepository({
    required this.apiClient,
    RouteService? routeService,
  }) : routeService = routeService ?? RouteService(apiClient);

  /// Récupère les modes de transport disponibles (Moto, Voiture, À pied)
  Future<List<TransportModeInfoModel>> getTransportModes() async {
    try {
      final response = await apiClient.get<dynamic>(ApiEndpoints.routeModes);
      final list = response.data as List<dynamic>;
      return list
          .map((m) => TransportModeInfoModel.fromJson(m as Map<String, dynamic>))
          .toList();
    } catch (e) {
      AppLogger.w('Modes de transport par défaut: $e');
      return const [
        TransportModeInfoModel(
          mode: 'moto',
          label: 'Moto Urbaine',
          description: 'Idéal pour le trafic urbain',
          averageSpeedKmh: 35.0,
        ),
        TransportModeInfoModel(
          mode: 'voiture',
          label: 'Voiture / Taxi',
          description: 'Véhicules 4 roues',
          averageSpeedKmh: 30.0,
        ),
        TransportModeInfoModel(
          mode: 'pied',
          label: 'À pied',
          description: 'Marche urbaine',
          averageSpeedKmh: 5.0,
        ),
      ];
    }
  }

  /// Calcule l'itinéraire réel entre des points via Valhalla
  Future<RouteModel> calculateRoute({
    required CoordinateModel origin,
    required CoordinateModel destination,
    List<CoordinateModel>? waypoints,
    String mode = 'moto',
  }) async {
    final points = <CoordinateModel>[
      origin,
      ...?waypoints,
      destination,
    ];

    return routeService.computeRoute(
      points: points,
      mode: mode,
    );
  }
}
