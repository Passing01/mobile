import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/enriched_maneuver_model.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/enriched_route_model.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/landmark_model.dart';
import 'package:qvgestion_mobile/features/guidance/data/repositories/guidance_repository.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

/// Provider du repository de guidage local
final guidanceRepositoryProvider = Provider<GuidanceRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return GuidanceRepository(apiClient: apiClient);
});

/// Provider de la liste des repères emblématiques (Landmarks)
final landmarksProvider = FutureProvider<List<LandmarkModel>>((ref) async {
  final repository = ref.watch(guidanceRepositoryProvider);
  return repository.getLandmarks();
});

/// Langue active pour le guidage vocal (Mooré 'mos' par défaut à Ouaga)
class GuidanceLanguageNotifier extends Notifier<String> {
  @override
  String build() => 'mos';

  void setLanguage(String lang) {
    if (['mos', 'diu', 'fr'].contains(lang.toLowerCase())) {
      state = lang.toLowerCase();
    }
  }
}

final guidanceLanguageProvider =
    NotifierProvider<GuidanceLanguageNotifier, String>(
  GuidanceLanguageNotifier.new,
);

/// Gestionnaire de l'itinéraire enrichi de consignes locales
class ActiveEnrichedRouteNotifier
    extends Notifier<AsyncValue<EnrichedRouteModel?>> {
  @override
  AsyncValue<EnrichedRouteModel?> build() {
    return const AsyncValue.data(null);
  }

  /// Enrichit l'itinéraire calculé avec les repères de la langue sélectionnée
  Future<EnrichedRouteModel?> enrichRoute({
    required RouteModel route,
    String? language,
  }) async {
    final String lang = language ?? ref.read(guidanceLanguageProvider);
    state = const AsyncValue.loading();

    try {
      final repository = ref.read(guidanceRepositoryProvider);
      final enriched = await repository.enrichRoute(
        route: route,
        language: lang,
      );
      state = AsyncValue.data(enriched);
      return enriched;
    } catch (e, stack) {
      AppLogger.e('Erreur lors de l\'enrichissement de route', e, stack);
      state = AsyncValue.error(e, stack);
      return null;
    }
  }

  void clear() {
    state = const AsyncValue.data(null);
  }
}

final activeEnrichedRouteProvider = NotifierProvider<
    ActiveEnrichedRouteNotifier, AsyncValue<EnrichedRouteModel?>>(
  ActiveEnrichedRouteNotifier.new,
);

/// Index de la manœuvre courante dans le guidage pas-à-pas (Écran 3)
class CurrentManeuverIndexNotifier extends Notifier<int> {
  @override
  int build() => 0;

  void next(int maxCount) {
    if (state < maxCount - 1) {
      state = state + 1;
    }
  }

  void previous() {
    if (state > 0) {
      state = state - 1;
    }
  }

  void setIndex(int index) {
    state = index;
  }

  void reset() {
    state = 0;
  }
}

final currentManeuverIndexProvider =
    NotifierProvider<CurrentManeuverIndexNotifier, int>(
  CurrentManeuverIndexNotifier.new,
);

/// Provider de la manœuvre actuellement active
final currentEnrichedManeuverProvider = Provider<EnrichedManeuverModel?>((ref) {
  final enrichedRouteAsync = ref.watch(activeEnrichedRouteProvider);
  final currentIndex = ref.watch(currentManeuverIndexProvider);

  final enrichedRoute = enrichedRouteAsync.value;
  if (enrichedRoute == null || enrichedRoute.enrichedManeuvers.isEmpty) {
    return null;
  }

  if (currentIndex >= 0 && currentIndex < enrichedRoute.enrichedManeuvers.length) {
    return enrichedRoute.enrichedManeuvers[currentIndex];
  }

  return enrichedRoute.enrichedManeuvers.first;
});
