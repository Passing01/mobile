import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/debug/debug_info.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
import 'package:qvgestion_mobile/core/errors/app_error_reporter.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';
import 'package:qvgestion_mobile/features/routes/data/repositories/routes_repository.dart';

/// Provider du repository des itinéraires
final routesRepositoryProvider = Provider<RoutesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return RoutesRepository(apiClient: apiClient);
});

/// Modes de transport disponibles depuis l'API (/routes/modes)
final transportModesProvider =
    FutureProvider<List<TransportModeInfoModel>>((ref) async {
  final repository = ref.watch(routesRepositoryProvider);
  return repository.getTransportModes();
});

/// Mode de transport sélectionné ('motorcycle', 'auto', 'bicycle', 'pedestrian')
class SelectedRouteModeNotifier extends Notifier<String> {
  @override
  String build() => 'motorcycle'; // Moto par défaut pour le contexte burkinabé

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

  /// Calcule l'itinéraire réel via l'endpoint /routes/calculate
  Future<RouteModel?> calculate({
    required CoordinateModel origin,
    required CoordinateModel destination,
    required String mode,
  }) async {
    AppLogger.d('[ActiveRouteNotifier.calculate] Début calcul mode=$mode, origin=${origin.lat},${origin.lon}, dest=${destination.lat},${destination.lon}');
    state = const AsyncValue.loading();
    try {
      final repository = ref.read(routesRepositoryProvider);
      final route = await repository.calculateRoute(
        origin: origin,
        destination: destination,
        mode: mode,
      );
      AppLogger.d('[ActiveRouteNotifier.calculate] Route reçue: ${route.distanceMeters}m, ${route.geometry.length} points. Mise à jour de state.');
      state = AsyncValue.data(route);
      AppLogger.d('[ActiveRouteNotifier.calculate] State mis à jour avec succès.');
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

/// Calcul comparatif de tous les modes pour la feuille de sélection (Écran 2)
final multiModeRoutesProvider =
    FutureProvider<Map<String, RouteModel>>((ref) async {
  final selectedPlace = ref.watch(selectedPlaceProvider);
  if (selectedPlace == null) return {};

  final currentLocation = ref.watch(currentLocationProvider);
  final repository = ref.watch(routesRepositoryProvider);
  final selectedMode = ref.watch(selectedRouteModeProvider);

  AppLogger.d('[multiModeRoutesProvider] Exécution pour selectedMode=$selectedMode');

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

  // 1. Récupérer ou calculer l'itinéraire pour le mode sélectionné
  final activeRouteState = ref.watch(activeRouteProvider);
  RouteModel? primaryRoute = activeRouteState.value;
  AppLogger.d('[multiModeRoutesProvider] activeRouteState isLoading=${activeRouteState.isLoading}, hasValue=${primaryRoute != null}');
  if (primaryRoute == null || primaryRoute.geometry.length < 2) {
    if (activeRouteState.isLoading) {
      AppLogger.d('[multiModeRoutesProvider] activeRouteState est loading, retour map vide temporaire');
      return {};
    }
    try {
      AppLogger.d('[multiModeRoutesProvider] Calcul de secours direct via repository pour $selectedMode');
      primaryRoute = await repository.calculateRoute(
        origin: origin,
        destination: destination,
        mode: selectedMode,
      );
    } catch (e) {
      AppLogger.w('Échec calcul itinéraire mode primaire ($selectedMode): $e');
    }
  }

  final results = <String, RouteModel>{};
  if (primaryRoute != null) {
    results[primaryRoute.mode] = primaryRoute;
    final dist = primaryRoute.distanceMeters;
    AppLogger.d('[multiModeRoutesProvider] Génération des 4 modes basés sur ${primaryRoute.mode} ($dist m)');

    // Vitesses moyennes calibrées selon les spécifications mobilité du Burkina Faso
    const modeSpeeds = {
      'motorcycle': 35.0, // Moto urbaine 35 km/h
      'auto': 30.0,       // Voiture 30 km/h
      'bicycle': 15.0,    // Vélo 15 km/h
      'pedestrian': 5.0,  // Piéton 5 km/h
    };

    for (final mode in ['motorcycle', 'auto', 'bicycle', 'pedestrian']) {
      if (!results.containsKey(mode)) {
        final speed = modeSpeeds[mode] ?? 30.0;
        final durSeconds = ((dist / (speed * 1000 / 3600))).round().clamp(60, 7200);
        final durMinutes = (durSeconds / 60).round().clamp(1, 180);

        results[mode] = RouteModel(
          mode: mode,
          distanceMeters: dist,
          durationSeconds: durSeconds,
          durationFormatted: '$durMinutes min',
          geometry: primaryRoute.geometry,
          boundingBox: primaryRoute.boundingBox,
          maneuvers: primaryRoute.maneuvers.map((item) {
            final stepDuration =
                ((item.distanceMeters / (speed * 1000 / 3600))).round();
            return ManeuverModel(
              order: item.order,
              instruction: item.instruction,
              streetName: item.streetName,
              maneuverType: item.maneuverType,
              distanceMeters: item.distanceMeters,
              durationSeconds: stepDuration,
              location: item.location,
            );
          }).toList(),
          engine: primaryRoute.engine,
        );
      }
    }
  }

  return results;
});
