import 'package:flutter/material.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';

/// Carte flottante d'aperçu d'un Lieu / POI (Correspondant à l'Écran 1 de la maquette)
class PoiPreviewCard extends StatelessWidget {
  final String title;
  final String category;
  final String distance;
  final String status;
  final String? culturalLandmark;
  final List<String> tags;
  final VoidCallback onNavigateMoto;
  final VoidCallback onNavigateAuto;
  final VoidCallback? onNavigateVelo;
  final VoidCallback? onNavigatePieton;
  final VoidCallback? onClose;

  const PoiPreviewCard({
    super.key,
    required this.title,
    required this.category,
    required this.distance,
    this.status = 'Ouvert actuellement',
    this.culturalLandmark,
    this.tags = const ['Goudronné', 'Piste deux-roues', '24h/24'],
    required this.onNavigateMoto,
    required this.onNavigateAuto,
    this.onNavigateVelo,
    this.onNavigatePieton,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // En-tête avec titre, catégorie et bouton fermer
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: AppColors.primaryLight,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.location_on_rounded,
                  color: AppColors.primary,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '$distance • $status',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondaryLight,
                      ),
                    ),
                  ],
                ),
              ),
              if (onClose != null)
                IconButton(
                  icon: const Icon(Icons.close_rounded, size: 20, color: Colors.grey),
                  onPressed: onClose,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          // Repère culturel local (Point de repère typique du Burkina Faso)
          if (culturalLandmark != null && culturalLandmark!.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF3F4F6),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.flag_rounded,
                    size: 16,
                    color: AppColors.primary,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Repère : $culturalLandmark',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          // Badges / Tags caractéristiques
          if (tags.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: tags.map((tag) {
                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF8F9FA),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                  ),
                  child: Text(
                    tag,
                    style: const TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
          const SizedBox(height: 16),
          // Bouton principal Itinéraire Moto + modes complémentaires (Auto, Vélo, À pied)
          Row(
            children: [
              Expanded(
                flex: 3,
                child: ElevatedButton.icon(
                  onPressed: onNavigateMoto,
                  icon: const Icon(Icons.two_wheeler_rounded, size: 18),
                  label: const Text('Itinéraire Moto'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    minimumSize: const Size.fromHeight(44),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 2,
                child: OutlinedButton.icon(
                  onPressed: onNavigateAuto,
                  icon: const Icon(Icons.directions_car_rounded, size: 16),
                  label: const Text('Auto'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.textPrimaryLight,
                    side: const BorderSide(color: Color(0xFFE5E7EB)),
                    minimumSize: const Size.fromHeight(44),
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                onPressed: onNavigateVelo ?? onNavigateMoto,
                icon: const Icon(Icons.pedal_bike_rounded, size: 18),
                tooltip: 'Vélo',
              ),
              const SizedBox(width: 6),
              IconButton.filledTonal(
                onPressed: onNavigatePieton ?? onNavigateAuto,
                icon: const Icon(Icons.directions_walk_rounded, size: 18),
                tooltip: 'À pied',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
