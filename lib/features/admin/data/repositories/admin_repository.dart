import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/admin/data/models/admin_dashboard_stats_model.dart';
import 'package:qvgestion_mobile/features/admin/data/models/api_key_model.dart';
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

  // ==========================================
  // --- B2B & API Keys (Monétisation & API) ---
  // ==========================================

  /// Liste toutes les clés API B2B/B2G
  Future<List<ApiKeyModel>> getApiKeys() async {
    try {
      final response = await apiClient.get<dynamic>(ApiEndpoints.adminApiKeys);
      final list = response.data as List<dynamic>? ?? [];
      return list
          .map((item) => ApiKeyModel.fromJson(item as Map<String, dynamic>))
          .toList();
    } catch (e, stack) {
      AppLogger.e('Erreur lors de la récupération des clés API B2B', e, stack);
      rethrow;
    }
  }

  /// Génère une nouvelle clé API B2B/B2G
  Future<ApiKeyModel> createApiKey({
    required String name,
    required String clientType,
    required String tier,
    required int monthlyQuota,
    String? description,
  }) async {
    try {
      final response = await apiClient.post<dynamic>(
        ApiEndpoints.adminApiKeys,
        data: {
          'name': name,
          'client_type': clientType,
          'tier': tier,
          'monthly_quota': monthlyQuota,
          'description': description,
        },
      );
      return ApiKeyModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stack) {
      AppLogger.e('Erreur lors de la création d\'une clé API B2B', e, stack);
      rethrow;
    }
  }

  /// Active ou suspend une clé API
  Future<ApiKeyModel> toggleApiKey(int id) async {
    try {
      final response = await apiClient.patch<dynamic>(
        ApiEndpoints.adminApiKeyToggle(id),
      );
      return ApiKeyModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e, stack) {
      AppLogger.e('Erreur lors du basculement du statut de la clé #$id', e, stack);
      rethrow;
    }
  }

  /// Révoque/supprime définitivement une clé API
  Future<bool> deleteApiKey(int id) async {
    try {
      await apiClient.delete<dynamic>(ApiEndpoints.adminApiKeyDelete(id));
      return true;
    } catch (e, stack) {
      AppLogger.e('Erreur lors de la suppression de la clé #$id', e, stack);
      rethrow;
    }
  }

  // ====================================================
  // --- Éditeur Carto Pro (GrabMaps style FASO NAV) ---
  // ====================================================

  /// Dépose un feu tricolore opérationnel pour le guidage vocal
  Future<Map<String, dynamic>> addTrafficSignal({
    required double latitude,
    required double longitude,
    required String name,
    String? crossroadName,
    String? direction,
  }) async {
    try {
      final response = await apiClient.post<dynamic>(
        ApiEndpoints.adminTrafficSignal,
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'name': name,
          'crossroad_name': crossroadName,
          'direction': direction,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e, stack) {
      AppLogger.e('Erreur lors de l\'ajout du feu tricolore', e, stack);
      rethrow;
    }
  }

  /// Déclare des travaux / maintenance voirie pour recalcul automatique du routage
  Future<Map<String, dynamic>> declareRoadMaintenance({
    required double latitude,
    required double longitude,
    required String title,
    required String description,
    int durationHours = 48,
  }) async {
    try {
      final response = await apiClient.post<dynamic>(
        ApiEndpoints.adminRoadMaintenance,
        data: {
          'latitude': latitude,
          'longitude': longitude,
          'title': title,
          'description': description,
          'duration_hours': durationHours,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e, stack) {
      AppLogger.e('Erreur lors de la déclaration de maintenance voirie', e, stack);
      rethrow;
    }
  }

  /// Trace une nouvelle voie / piste / 6-mètres dans le graphe routier
  Future<Map<String, dynamic>> traceRoad({
    required String name,
    required String roadType,
    required String surface,
    required List<Map<String, double>> coordinates,
    int widthMeters = 6,
    bool isOneWay = false,
  }) async {
    try {
      final response = await apiClient.post<dynamic>(
        ApiEndpoints.adminRoadTrace,
        data: {
          'name': name,
          'road_type': roadType,
          'surface': surface,
          'coordinates': coordinates,
          'width_meters': widthMeters,
          'is_one_way': isOneWay,
        },
      );
      return response.data as Map<String, dynamic>;
    } catch (e, stack) {
      AppLogger.e('Erreur lors du traçage de la nouvelle voie', e, stack);
      rethrow;
    }
  }
}
