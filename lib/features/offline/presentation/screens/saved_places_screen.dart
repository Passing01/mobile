import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/features/offline/data/models/offline_pack_model.dart';
import 'package:qvgestion_mobile/features/offline/presentation/providers/offline_providers.dart';
import 'package:qvgestion_mobile/features/offline/presentation/widgets/offline_pois_modal.dart';

/// Onglet 3 officiel : Lieux sauvegardés & Cartes hors-ligne (PMTiles)
/// Entièrement dynamique et connecté à l'API Railway
class SavedPlacesScreen extends ConsumerWidget {
  const SavedPlacesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final availablePacksAsync = ref.watch(availableOfflinePacksProvider);
    final installedState = ref.watch(installedPacksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Sauvegardés & Hors-Ligne',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            onPressed: () {
              ref.invalidate(availableOfflinePacksProvider);
              AppSnackbar.showInfo(
                context,
                title: 'Synchronisation',
                message: 'Vérification des packs régionaux sur le serveur...',
              );
            },
            icon: const Icon(Icons.refresh_rounded, color: Color(0xFF374151)),
            tooltip: 'Rafraîchir les packs',
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // 1. BANNIÈRE D'ÉTAT DU STOCKAGE HORS-LIGNE
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFECFDF5),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: const Color(0xFFA7F3D0)),
            ),
            child: Row(
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: const BoxDecoration(
                    color: Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.offline_pin_rounded,
                      color: Colors.white, size: 26),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mode Hors-Ligne Opérationnel',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        '${installedState.installedPacks.length} région(s) installée(s) • '
                        '${installedState.totalStorageUsedMo.toStringAsFixed(1)} Mo • '
                        '${installedState.totalOfflinePoisCount} POI indexés',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Color(0xFF047857),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 22),

          // 2. SECTION DES PACKS RÉGIONAUX (Connectée au backend)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Packs Régionaux Burkina Faso',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                'Format PMTiles',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
              ),
            ],
          ),
          const SizedBox(height: 12),

          availablePacksAsync.when(
            data: (packs) {
              if (packs.isEmpty) {
                return const Center(
                  child: Text('Aucun pack cartographique disponible.'),
                );
              }

              return Column(
                children: packs.map((pack) {
                  final isDownloaded =
                      installedState.isInstalled(pack.regionId);
                  final isDownloading =
                      installedState.isDownloading(pack.regionId);
                  final progress =
                      installedState.getProgress(pack.regionId) ?? 0.0;

                  return _buildPackCard(
                    context,
                    ref: ref,
                    pack: pack,
                    isDownloaded: isDownloaded,
                    isDownloading: isDownloading,
                    downloadProgress: progress,
                  );
                }).toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (e, _) => Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFFECACA)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFDC2626)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Erreur de récupération des packs : $e',
                      style: const TextStyle(fontSize: 12),
                    ),
                  ),
                  TextButton(
                    onPressed: () =>
                        ref.invalidate(availableOfflinePacksProvider),
                    child: const Text('Réessayer'),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // 3. SECTION DES LIEUX FAVORIS
          const Text(
            'Mes Lieux Favoris',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          _buildFavoriteItem(
            name: 'Pharmacie du 1200 Logements',
            subtitle: '1200 Logements • Ouvert 24h/24',
            icon: Icons.local_pharmacy_rounded,
            onTap: () {
              AppSnackbar.showInfo(
                context,
                title: 'Favori',
                message: 'Pharmacie 1200 Logements prête pour la navigation.',
              );
            },
          ),
          _buildFavoriteItem(
            name: 'Grand Marché Rood-Woko',
            subtitle: 'Centre-Ville • Marché central',
            icon: Icons.storefront_rounded,
            onTap: () {
              AppSnackbar.showInfo(
                context,
                title: 'Favori',
                message: 'Grand Marché Rood-Woko prêt pour la navigation.',
              );
            },
          ),
          _buildFavoriteItem(
            name: 'Total Échangeur de l\'Est',
            subtitle: 'Dassasgho • Station & Gonflage moto',
            icon: Icons.local_gas_station_rounded,
            onTap: () {
              AppSnackbar.showInfo(
                context,
                title: 'Favori',
                message: 'Station Total Échangeur de l\'Est prête.',
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPackCard(
    BuildContext context, {
    required WidgetRef ref,
    required OfflinePackModel pack,
    required bool isDownloaded,
    required bool isDownloading,
    required double downloadProgress,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isDownloaded
              ? const Color(0xFFA7F3D0)
              : const Color(0xFFE5E7EB),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: isDownloaded
                      ? const Color(0xFFECFDF5)
                      : AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  pack.iconData,
                  color: isDownloaded
                      ? const Color(0xFF10B981)
                      : AppColors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      pack.nomRegion,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF111827),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${pack.formattedSize} • ${pack.poiCount} POI • v${pack.version}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              if (isDownloaded) ...[
                // Bouton Consulter les POIs du pack
                IconButton(
                  onPressed: () => OfflinePoisModal.show(context, pack),
                  icon: const Icon(Icons.visibility_outlined,
                      size: 20, color: Color(0xFF374151)),
                  tooltip: 'Voir les POIs indexés',
                ),
                // Bouton Supprimer pour libérer l'espace
                IconButton(
                  onPressed: () {
                    ref
                        .read(installedPacksProvider.notifier)
                        .removePack(pack.regionId);
                    AppSnackbar.showInfo(
                      context,
                      title: 'Espace libéré',
                      message: 'Le pack ${pack.nomRegion} a été supprimé.',
                    );
                  },
                  icon: const Icon(Icons.delete_outline_rounded,
                      size: 20, color: Color(0xFFEF4444)),
                  tooltip: 'Supprimer le pack',
                ),
              ] else if (isDownloading) ...[
                Text(
                  '${(downloadProgress * 100).toInt()}%',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ] else ...[
                ElevatedButton.icon(
                  onPressed: () {
                    ref
                        .read(installedPacksProvider.notifier)
                        .downloadPack(pack);
                    AppSnackbar.showSuccess(
                      context,
                      title: 'Téléchargement démarré',
                      message:
                          'Téléchargement de ${pack.nomRegion} avec reprise HTTP Range (206)...',
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 8),
                    minimumSize: Size.zero,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  icon: const Icon(Icons.cloud_download_rounded, size: 14),
                  label: const Text('Télécharger', style: TextStyle(fontSize: 11)),
                ),
              ],
            ],
          ),

          // Barre de progression si téléchargement en cours
          if (isDownloading) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: downloadProgress,
                backgroundColor: const Color(0xFFE5E7EB),
                valueColor:
                    const AlwaysStoppedAnimation<Color>(AppColors.primary),
                minHeight: 6,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFavoriteItem({
    required String name,
    required String subtitle,
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: ListTile(
          contentPadding: EdgeInsets.zero,
          onTap: onTap,
          leading: CircleAvatar(
            backgroundColor: AppColors.primaryLight,
            child: Icon(icon, color: AppColors.primary, size: 20),
          ),
          title: Text(
            name,
            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
          ),
          subtitle: Text(subtitle, style: const TextStyle(fontSize: 11)),
          trailing: const Icon(Icons.favorite_rounded, color: Color(0xFFEF4444)),
        ),
      ),
    );
  }
}
