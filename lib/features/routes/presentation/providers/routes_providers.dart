import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/debug/debug_info.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
import 'package:qvgestion_mobile/core/errors/app_error_reporter.dart';
import 'package:qvgestion_mobile/core/services/location_service.dart';
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

  void setRoute(RouteModel route) {
    state = AsyncValue.data(route);
    DebugInfo.instance.setRoute(
      points: route.geometry.length,
      distanceM: route.distanceMeters,
      durationS: route.durationSeconds.toDouble(),
    );
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

/// Calcul comparatif des modes réels (calculé une seule fois par destination choisie, sans scintillement GPS)
final multiModeRoutesProvider =
    FutureProvider<Map<String, RouteModel>>((ref) async {
  final selectedPlace = ref.watch(selectedPlaceProvider);
  if (selectedPlace == null) return {};

  final locService = ref.read(locationServiceProvider);
  final lastGps = locService.last;
  final currentLocation = ref.read(currentLocationProvider);
  final repository = ref.watch(routesRepositoryProvider);

  final origin = (lastGps != null)
      ? CoordinateModel(
          lat: lastGps.latitude,
          lon: lastGps.longitude,
          name: 'Ma position GPS',
        )
      : CoordinateModel(
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
  final modesToFetch = ['moto', 'voiture', 'pied'];

  await Future.wait(
    modesToFetch.map((m) async {
      try {
        final route = await repository.calculateRoute(
          origin: origin,
          destination: destination,
          mode: m,
        );
        results[m] = route;
        results[route.mode] = route;
        if (m == 'moto' || route.mode == 'moto') {
          results['motorcycle'] = route;
        }
        if (m == 'voiture' || route.mode == 'voiture') {
          results['auto'] = route;
        }
        if (m == 'pied' || route.mode == 'pied') {
          results['pedestrian'] = route;
          final bikeSec = (route.distanceMeters / 4.1667).round();
          final bikeFormatted = bikeSec < 60
              ? '${bikeSec}s'
              : bikeSec < 3600
                  ? '${(bikeSec / 60).round()} min'
                  : '${bikeSec ~/ 3600} h ${(bikeSec % 3600 ~/ 60)} min';
          final bikeRoute = route.copyWith(
            mode: 'velo',
            durationSeconds: bikeSec,
            durationFormatted: bikeFormatted,
          );
          results['bicycle'] = bikeRoute;
          results['velo'] = bikeRoute;
        }
      } catch (e) {
        AppLogger.w('Échec calcul itinéraire comparatif mode $m: $e');
      }
    }),
  );

  return results;
});
