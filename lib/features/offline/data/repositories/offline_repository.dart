import 'package:qvgestion_mobile/core/config/env_config.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/offline/data/models/offline_pack_model.dart';
import 'package:qvgestion_mobile/features/offline/data/models/offline_pois_export_model.dart';

/// Repository pour interagir avec le gestionnaire de packs hors-ligne (Étape 7)
class OfflineRepository {
  final ApiClient apiClient;

  OfflineRepository({required this.apiClient});

  /// Récupère la liste de tous les packs cartographiques régionaux disponibles (GET /api/v1/offline/packs)
  Future<List<OfflinePackModel>> getAvailablePacks() async {
    try {
      final response = await apiClient.get<dynamic>(ApiEndpoints.offlinePacks);
      final list = response.data as List<dynamic>? ?? [];
      final packs = list
          .map((item) => OfflinePackModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return packs.isNotEmpty ? packs : defaultRegionalPacks;
    } catch (e) {
      AppLogger.w('Packs distants inaccessibles ($e). Utilisation du catalogue local.');
      return defaultRegionalPacks;
    }
  }

  /// Récupère l'index compact des POIs d'une région (GET /api/v1/offline/packs/{id}/pois)
  Future<OfflinePoisExportModel> getRegionPois(String regionId) async {
    try {
      final response = await apiClient.get<dynamic>(
        ApiEndpoints.offlinePackPois(regionId),
      );
      return OfflinePoisExportModel.fromJson(
        response.data as Map<String, dynamic>,
      );
    } catch (e, stack) {
      AppLogger.e('Erreur lors de l\'export des POIs de la région $regionId', e, stack);
      rethrow;
    }
  }

  /// Vérifie si des mises à jour sont disponibles pour les packs installés (POST /api/v1/offline/check-updates)
  Future<Map<String, dynamic>> checkUpdates(
    List<Map<String, String>> installedPacks,
  ) async {
    try {
      final response = await apiClient.post<dynamic>(
        ApiEndpoints.offlineCheckUpdates,
        data: {'installed_packs': installedPacks},
      );
      return response.data as Map<String, dynamic>? ?? {};
    } catch (e, stack) {
      AppLogger.e('Erreur lors de la vérification des mises à jour de packs', e, stack);
      rethrow;
    }
  }

  /// Retourne l'URL de téléchargement direct avec support HTTP Range (206)
  String getPackDownloadUrl(String regionId) {
    return '${EnvConfig.apiBaseUrl}${ApiEndpoints.offlinePackDownload(regionId)}';
  }
}

/// Packs régionaux essentiels pré-indexés pour le Burkina Faso
const List<OfflinePackModel> defaultRegionalPacks = [
  OfflinePackModel(
    regionId: 'centre-ouaga',
    nomRegion: 'Centre (Ouagadougou)',
    description: 'Cartographie de Ouagadougou et ses arrondissements',
    tailleOctets: 45000000,
    tailleMo: 42.9,
    version: '1.2.0',
    sha256Checksum: 'default_centre_checksum',
    poiCount: 1520,
    boundingBox: [12.28, -1.60, 12.45, -1.43],
  ),
  OfflinePackModel(
    regionId: 'hauts-bassins-bobo',
    nomRegion: 'Hauts-Bassins (Bobo-Dioulasso)',
    description: 'Cartographie de Bobo-Dioulasso et ses grands axes',
    tailleOctets: 38000000,
    tailleMo: 36.2,
    version: '1.1.0',
    sha256Checksum: 'default_bobo_checksum',
    poiCount: 980,
    boundingBox: [11.12, -4.35, 11.24, -4.22],
  ),
  OfflinePackModel(
    regionId: 'centre-ouest-koudougou',
    nomRegion: 'Centre-Ouest (Koudougou)',
    description: 'Cartographie de Koudougou et environs',
    tailleOctets: 22000000,
    tailleMo: 21.0,
    version: '1.0.0',
    sha256Checksum: 'default_koudougou_checksum',
    poiCount: 450,
    boundingBox: [12.20, -2.42, 12.30, -2.30],
  ),
];

