import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/offline/data/models/offline_pack_model.dart';
import 'package:qvgestion_mobile/features/offline/data/models/offline_pois_export_model.dart';
import 'package:qvgestion_mobile/features/offline/data/repositories/offline_repository.dart';

/// Provider d'accès au repository offline
final offlineRepositoryProvider = Provider<OfflineRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return OfflineRepository(apiClient: apiClient);
});

/// Provider de la liste des packs disponibles sur le serveur
final availableOfflinePacksProvider =
    FutureProvider<List<OfflinePackModel>>((ref) async {
  final repository = ref.watch(offlineRepositoryProvider);
  return repository.getAvailablePacks();
});

/// État global des packs installés sur le smartphone
class InstalledPacksState {
  final Map<String, OfflinePackModel> installedPacks;
  final Map<String, double> downloadingProgress;

  const InstalledPacksState({
    this.installedPacks = const {},
    this.downloadingProgress = const {},
  });

  InstalledPacksState copyWith({
    Map<String, OfflinePackModel>? installedPacks,
    Map<String, double>? downloadingProgress,
  }) {
    return InstalledPacksState(
      installedPacks: installedPacks ?? this.installedPacks,
      downloadingProgress: downloadingProgress ?? this.downloadingProgress,
    );
  }

  /// Espace disque total consommé par les tuiles vectorielles (en Mo)
  double get totalStorageUsedMo {
    return installedPacks.values
        .fold(0.0, (acc, pack) => acc + pack.tailleMo);
  }

  /// Total de lieux d'intérêts disponibles sans connexion
  int get totalOfflinePoisCount {
    return installedPacks.values
        .fold(0, (acc, pack) => acc + pack.poiCount);
  }

  bool isInstalled(String regionId) => installedPacks.containsKey(regionId);
  bool isDownloading(String regionId) => downloadingProgress.containsKey(regionId);
  double? getProgress(String regionId) => downloadingProgress[regionId];
}

class InstalledPacksNotifier extends Notifier<InstalledPacksState> {
  @override
  InstalledPacksState build() {
    // Par défaut : la Région du Centre (Ouagadougou) est préinstallée
    const defaultOuaga = OfflinePackModel(
      regionId: 'centre-ouagadougou',
      nomRegion: 'Région du Centre (Ouagadougou)',
      description: 'Tuiles vectorielles haute résolution de la capitale Ouagadougou et de la province du Kadiogo.',
      tailleOctets: 47185920,
      tailleMo: 45.0,
      version: '2026.09.1',
      sha256Checksum: '7ca9649503bdf5b87f113c5097fd276bc85f4a2f844faa4bc0507f43e942b01b',
      isDownloaded: true,
      poiCount: 1420,
    );

    return const InstalledPacksState(
      installedPacks: {'centre-ouagadougou': defaultOuaga},
    );
  }

  /// Démarre le téléchargement d'un pack régional avec progression
  Future<void> downloadPack(OfflinePackModel pack) async {
    final regionId = pack.regionId;
    if (state.isInstalled(regionId) || state.isDownloading(regionId)) return;

    // Étape 1 : Initialisation
    final newProgress = Map<String, double>.from(state.downloadingProgress);
    newProgress[regionId] = 0.15;
    state = state.copyWith(downloadingProgress: newProgress);

    try {
      // Simulation fluide de progression des tranches HTTP Range (206)
      await Future<void>.delayed(const Duration(milliseconds: 300));
      newProgress[regionId] = 0.45;
      state = state.copyWith(downloadingProgress: Map.from(newProgress));

      await Future<void>.delayed(const Duration(milliseconds: 350));
      newProgress[regionId] = 0.80;
      state = state.copyWith(downloadingProgress: Map.from(newProgress));

      await Future<void>.delayed(const Duration(milliseconds: 300));

      // Téléchargement et indexation réussis
      final updatedPacks = Map<String, OfflinePackModel>.from(state.installedPacks);
      updatedPacks[regionId] = pack.copyWith(isDownloaded: true);

      newProgress.remove(regionId);
      state = state.copyWith(
        installedPacks: updatedPacks,
        downloadingProgress: newProgress,
      );

      AppLogger.i('Pack $regionId téléchargé avec succès pour utilisation hors-ligne.');
    } catch (e, stack) {
      AppLogger.e('Erreur lors du téléchargement du pack $regionId', e, stack);
      newProgress.remove(regionId);
      state = state.copyWith(downloadingProgress: newProgress);
    }
  }

  /// Supprime un pack installé pour libérer de l'espace de stockage
  void removePack(String regionId) {
    if (!state.isInstalled(regionId)) return;

    final updatedPacks = Map<String, OfflinePackModel>.from(state.installedPacks);
    updatedPacks.remove(regionId);
    state = state.copyWith(installedPacks: updatedPacks);
    AppLogger.i('Pack $regionId supprimé du stockage local.');
  }
}

final installedPacksProvider =
    NotifierProvider<InstalledPacksNotifier, InstalledPacksState>(
  InstalledPacksNotifier.new,
);

/// Provider de l'export des POIs d'une région sélectionnée
final regionPoisProvider =
    FutureProvider.family<OfflinePoisExportModel, String>((ref, regionId) async {
  final repository = ref.watch(offlineRepositoryProvider);
  return repository.getRegionPois(regionId);
});
