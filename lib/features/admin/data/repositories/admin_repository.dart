import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/admin/data/models/admin_dashboard_stats_model.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/road_feature_model.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';

/// Repository pour les actions et vues d'administration FASO NAV
class AdminRepository {
  final ApiClient apiClient;

  AdminRepository({required this.apiClient});

  /// Récupère les métriques statistiques globales du backend
  Future<AdminDashboardStatsModel> getDashboardStats() async {
    try {
      final response = await apiClient.get<dynamic>(ApiEndpoints.adminDashboard);
      return AdminDashboardStatsModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stack) {
      AppLogger.e('Erreur lors de la récupération des stats admin', e, stack);
      rethrow;
    }
  }

  /// Récupère la liste des lieux soumis en attente de modération
  Future<List<PlaceModel>> getPendingPlaces() async {
    try {
      final response = await apiClient.get<dynamic>(ApiEndpoints.adminPendingPlaces);
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((item) => PlaceModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      AppLogger.e('Erreur lors de la récupération des lieux en attente', e, stack);
      rethrow;
    }
  }

  /// Valide ou rejette un lieu soumis
  Future<PlaceModel> moderatePlace({
    required int placeId,
    required bool approve,
    String? reason,
  }) async {
    try {
      final response = await apiClient.post<dynamic>(
        ApiEndpoints.adminModeratePlace(placeId),
        data: {
          'action': approve ? 'approve' : 'reject',
          'motif': ?reason,
        },
      );
      return PlaceModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stack) {
      AppLogger.e('Erreur lors de la modération du lieu #$placeId', e, stack);
      rethrow;
    }
  }

  /// Récupère la liste des éléments routiers remarquables (feux, ponts, échangeurs)
  Future<List<RoadFeatureModel>> getRoadFeatures({String? kind}) async {
    try {
      final queryParams = <String, dynamic>{};
      if (kind != null) queryParams['kind'] = kind;
      final response = await apiClient.get<dynamic>(
        ApiEndpoints.adminRoadFeatures,
        queryParameters: queryParams,
      );
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((item) => RoadFeatureModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      AppLogger.e('Erreur lors de la récupération des éléments routiers', e, stack);
      rethrow;
    }
  }

  /// Ajoute un nouvel élément routier remarquable
  Future<RoadFeatureModel> createRoadFeature(Map<String, dynamic> data) async {
    try {
      final response = await apiClient.post<dynamic>(
        ApiEndpoints.adminRoadFeatures,
        data: data,
      );
      return RoadFeatureModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stack) {
      AppLogger.e('Erreur lors de la création d\'un élément routier', e, stack);
      rethrow;
    }
  }
}
