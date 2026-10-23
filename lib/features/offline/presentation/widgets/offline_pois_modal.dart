import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/features/offline/data/models/offline_pack_model.dart';
import 'package:qvgestion_mobile/features/offline/presentation/providers/offline_providers.dart';

/// Modal affichant les points d'intérêts indexés dans un pack régional hors-ligne
class OfflinePoisModal extends ConsumerWidget {
  final OfflinePackModel pack;

  const OfflinePoisModal({super.key, required this.pack});

  static Future<void> show(BuildContext context, OfflinePackModel pack) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => OfflinePoisModal(pack: pack),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poisAsync = ref.watch(regionPoisProvider(pack.regionId));

    return Container(
      height: MediaQuery.of(context).size.height * 0.72,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: SafeArea(
        top: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Barre de préhension
            Center(
              child: Container(
                width: 44,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: Colors.grey.shade300,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),

            // En-tête du pack
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(pack.iconData, color: AppColors.primary, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        pack.nomRegion,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Version ${pack.version} • ${pack.formattedSize}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF6B7280)),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.grey),
                ),
              ],
            ),

            const SizedBox(height: 14),

            // Bannière descriptive
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF9FAFB),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE5E7EB)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.offline_pin_rounded,
                      color: Color(0xFF10B981), size: 18),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${pack.poiCount} lieux d\'intérêt indexés pour recherche sans connexion.',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            const Text(
              'Lieux indispensables de la région :',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.bold,
                color: Color(0xFF374151),
              ),
            ),
            const SizedBox(height: 8),

            // Liste des POIs indexés
            Expanded(
              child: poisAsync.when(
                data: (export) {
                  final pois = export.pois;
                  if (pois.isEmpty) {
                    return const Center(
                      child: Text('Aucun lieu indexé pour cette région.'),
                    );
                  }

                  return ListView.separated(
                    itemCount: pois.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final poi = pois[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: AppColors.primaryLight,
                          child: Icon(
                            poi.categorieSlug == 'pharmacie'
                                ? Icons.local_pharmacy_rounded
                                : poi.categorieSlug == 'station-service'
                                    ? Icons.local_gas_station_rounded
                                    : poi.categorieSlug == 'hopital-sante'
                                        ? Icons.local_hospital_rounded
                                        : Icons.place_rounded,
                            color: AppColors.primary,
                            size: 18,
                          ),
                        ),
                        title: Text(
                          poi.nom,
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        subtitle: Text(
                          poi.quartier != null
                              ? 'Quartier ${poi.quartier}'
                              : 'Ouagadougou',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                        trailing: poi.telephone != null
                            ? Text(
                                poi.telephone!,
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                  color: AppColors.primary,
                                ),
                              )
                            : null,
                      );
                    },
                  );
                },
                loading: () => const Center(
                  child: CircularProgressIndicator(),
                ),
                error: (e, _) => Center(
                  child: Text('Erreur de chargement des lieux : $e'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
