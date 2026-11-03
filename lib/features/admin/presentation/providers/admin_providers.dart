import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
import 'package:qvgestion_mobile/features/admin/data/models/admin_dashboard_stats_model.dart';
import 'package:qvgestion_mobile/features/admin/data/models/api_key_model.dart';
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

  Future<void> moderate({required int placeId, required bool approve, String? reason}) async {
    final repo = ref.read(adminRepositoryProvider);
    await repo.moderatePlace(placeId: placeId, approve: approve, reason: reason);
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

/// Notifier pour gérer les clés API B2B / B2G (SAMU, BNSP, Livraison, VTC, etc.)
class ApiKeysNotifier extends AsyncNotifier<List<ApiKeyModel>> {
  @override
  Future<List<ApiKeyModel>> build() async {
    final repo = ref.watch(adminRepositoryProvider);
    return repo.getApiKeys();
  }

  Future<ApiKeyModel> createKey({
    required String name,
    required String clientType,
    required String tier,
    required int monthlyQuota,
    String? description,
  }) async {
    final repo = ref.read(adminRepositoryProvider);
    final newKey = await repo.createApiKey(
      name: name,
      clientType: clientType,
      tier: tier,
      monthlyQuota: monthlyQuota,
      description: description,
    );
    ref.invalidateSelf();
    return newKey;
  }

  Future<void> toggleKey(int id) async {
    final repo = ref.read(adminRepositoryProvider);
    await repo.toggleApiKey(id);
    ref.invalidateSelf();
  }

  Future<void> deleteKey(int id) async {
    final repo = ref.read(adminRepositoryProvider);
    await repo.deleteApiKey(id);
    ref.invalidateSelf();
  }
}

final adminApiKeysProvider =
    AsyncNotifierProvider<ApiKeysNotifier, List<ApiKeyModel>>(
  ApiKeysNotifier.new,
);
