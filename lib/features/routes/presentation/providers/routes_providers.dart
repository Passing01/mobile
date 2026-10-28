import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/debug/debug_info.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
import 'package:qvgestion_mobile/core/errors/app_error_reporter.dart';
import 'package:qvgestion_mobile/core/services/route_service.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';
import 'package:qvgestion_mobile/features/routes/data/repositories/routes_repository.dart';

/// Provider du repository des itinéraires
final routesRepositoryProvider = Provider<RoutesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final routeService = ref.watch(routeServiceProvider);
  return RoutesRepository(apiClient: apiClient, routeService: routeService);
});

/// Modes de transport disponibles depuis l'API (/routes/modes)
final transportModesProvider =
    FutureProvider<List<TransportModeInfoModel>>((ref) async {
  final repository = ref.watch(routesRepositoryProvider);
  return repository.getTransportModes();
});

/// Mode de transport sélectionné ('moto', 'voiture', 'pied')
class SelectedRouteModeNotifier extends Notifier<String> {
  @override
  String build() => 'moto';

  void selectMode(String mode) => state = mode;
}

final selectedRouteModeProvider =
    NotifierProvider<SelectedRouteModeNotifier, String>(
  SelectedRouteModeNotifier.new,
);

/// État du calcul d'itinéraire actif
class ActiveRouteNotifier extends Notifier<AsyncValue<RouteModel?>> {
  @override
  AsyncValue<RouteModel?> build() {
    return const AsyncValue.data(null);
  }

  /// Calcule l'itinéraire réel via POST /api/v1/routes
  Future<RouteModel?> calculate({
    required CoordinateModel origin,
    required CoordinateModel destination,
    List<CoordinateModel>? waypoints,
    required String mode,
  }) async {
    AppLogger.d(
        '[ActiveRouteNotifier.calculate] Début calcul mode=$mode, origin=${origin.lat},${origin.lon}, dest=${destination.lat},${destination.lon}');
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(routesRepositoryProvider);
      final route = await repository.calculateRoute(
        origin: origin,
        destination: destination,
        waypoints: waypoints,
        mode: mode,
      );
      AppLogger.d(
          '[ActiveRouteNotifier.calculate] Route reçue: ${route.distanceMeters}m, ${route.geometry.length} points.');
      state = AsyncValue.data(route);
      DebugInfo.instance.setRoute(
        points: route.geometry.length,
        distanceM: route.distanceMeters,
        durationS: route.durationSeconds.toDouble(),
      );
      return route;
    } catch (e, st) {
      AppErrorReporter.reportError(
        'Erreur lors du calcul d\'itinéraire',
        error: e,
        stackTrace: st,
        tag: 'RoutingAPI',
      );
      state = AsyncValue.error(e, st);
      DebugInfo.instance.clearRoute();
      return null;
    }
  }

  void clear() {
    state = const AsyncValue.data(null);
    DebugInfo.instance.clearRoute();
  }
}

final activeRouteProvider =
    NotifierProvider<ActiveRouteNotifier, AsyncValue<RouteModel?>>(
  ActiveRouteNotifier.new,
);

/// Calcul comparatif des modes réels
final multiModeRoutesProvider =
    FutureProvider<Map<String, RouteModel>>((ref) async {
  final selectedPlace = ref.watch(selectedPlaceProvider);
  if (selectedPlace == null) return {};

  final currentLocation = ref.watch(currentLocationProvider);
  final repository = ref.watch(routesRepositoryProvider);
  final selectedMode = ref.watch(selectedRouteModeProvider);

  final origin = CoordinateModel(
    lat: currentLocation.lat,
    lon: currentLocation.lon,
    name: currentLocation.label,
  );
  final destination = CoordinateModel(
    lat: selectedPlace.latitude,
    lon: selectedPlace.longitude,
    name: selectedPlace.nom,
  );

  final results = <String, RouteModel>{};
  try {
    final route = await repository.calculateRoute(
      origin: origin,
      destination: destination,
      mode: selectedMode,
    );
    results[route.mode] = route;
  } catch (e) {
    AppLogger.w('Échec calcul itinéraire mode $selectedMode: $e');
  }

  return results;
});
