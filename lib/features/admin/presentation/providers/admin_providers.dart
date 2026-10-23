import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
import 'package:qvgestion_mobile/features/admin/data/models/admin_dashboard_stats_model.dart';
import 'package:qvgestion_mobile/features/admin/data/repositories/admin_repository.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/road_feature_model.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return AdminRepository(apiClient: apiClient);
});

final adminDashboardStatsProvider = FutureProvider<AdminDashboardStatsModel>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getDashboardStats();
});

class PendingPlacesNotifier extends AsyncNotifier<List<PlaceModel>> {
  @override
  Future<List<PlaceModel>> build() async {
    final repo = ref.watch(adminRepositoryProvider);
    return repo.getPendingPlaces();
  }

  Future<void> moderate({required int placeId, required bool approve}) async {
    final repo = ref.read(adminRepositoryProvider);
    await repo.moderatePlace(placeId: placeId, approve: approve);
    // Rafraîchir la liste
    ref.invalidateSelf();
  }
}

final pendingPlacesProvider =
    AsyncNotifierProvider<PendingPlacesNotifier, List<PlaceModel>>(
  PendingPlacesNotifier.new,
);

final adminRoadFeaturesProvider = FutureProvider<List<RoadFeatureModel>>((ref) async {
  final repo = ref.watch(adminRepositoryProvider);
  return repo.getRoadFeatures();
});
