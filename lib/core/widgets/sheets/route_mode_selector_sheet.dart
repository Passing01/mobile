import 'package:flutter/material.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';

class RouteModeOption {
  final String id;
  final String title;
  final String subtitle;
  final String duration;
  final String distance;
  final IconData icon;
  final bool isRecommended;

  const RouteModeOption({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.duration,
    required this.distance,
    required this.icon,
    this.isRecommended = false,
  });
}

/// Feuille de sélection du mode de transport (Correspondant à l'Écran 2 de la maquette)
class RouteModeSelectorSheet extends StatelessWidget {
  final String originName;
  final String destinationName;
  final List<RouteModeOption> options;
  final String selectedModeId;
  final ValueChanged<String> onModeSelected;
  final VoidCallback onConfirm;
  final VoidCallback? onBack;

  const RouteModeSelectorSheet({
    super.key,
    required this.originName,
    required this.destinationName,
    required this.options,
    required this.selectedModeId,
    required this.onModeSelected,
    required this.onConfirm,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 20,
            offset: Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Poignée de glissement (Drag Handle)
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // En-tête de trajet avec bouton Annuler (X)
              Row(
                children: [
                  if (onBack != null)
                    IconButton(
                      key: const Key('btn_back_route_selection'),
                      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                      onPressed: onBack,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Annuler l\'itinéraire',
                    ),
                  Expanded(
                    child: Text(
                      '$originName ➔ $destinationName',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (onBack != null)
                    IconButton(
                      key: const Key('btn_close_route_selection'),
                      icon: const Icon(Icons.close_rounded, size: 20, color: Color(0xFFDC2626)),
                      onPressed: onBack,
                      visualDensity: VisualDensity.compact,
                      tooltip: 'Annuler l\'itinéraire',
                    ),
                ],
              ),
              const SizedBox(height: 4),
              // Titre de section
              const Text(
                'Choisir votre moyen de déplacement',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondaryLight,
                ),
              ),
              const SizedBox(height: 8),
              // Liste compacte des modes (permettant de voir clairement la carte au-dessus)
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 210),
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: options.map((option) {
                      final isSelected = option.id == selectedModeId;
                      return GestureDetector(
                        onTap: () => onModeSelected(option.id),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          margin: const EdgeInsets.only(bottom: 6),
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primaryLight : const Color(0xFFF9FAFB),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: isSelected ? AppColors.primary : Colors.white,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Icon(
                                  option.icon,
                                  color: isSelected ? Colors.white : AppColors.primary,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Flexible(
                                          child: Text(
                                            option.title,
                                            style: TextStyle(
                                              fontSize: 13,
                                              fontWeight: FontWeight.bold,
                                              color: isSelected
                                                  ? AppColors.primary
                                                  : AppColors.textPrimaryLight,
                                            ),
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        ),
                                        if (option.isRecommended) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                                horizontal: 5, vertical: 1),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius: BorderRadius.circular(5),
                                            ),
                                            child: const Text(
                                              'Recommandé',
                                              style: TextStyle(
                                                color: Colors.white,
                                                fontSize: 9,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                    Text(
                                      option.subtitle,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: AppColors.textSecondaryLight,
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    option.duration,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  Text(
                                    option.distance,
                                    style: const TextStyle(
                                      fontSize: 11,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              // Boutons Annuler + Démarrer la navigation vocale
              Row(
                children: [
                  if (onBack != null) ...[
                    OutlinedButton.icon(
                      key: const Key('btn_cancel_route_preview'),
                      onPressed: onBack,
                      icon: const Icon(Icons.close_rounded, size: 18, color: Color(0xFFDC2626)),
                      label: const Text(
                        'Annuler',
                        style: TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size(0, 46),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        side: const BorderSide(color: Color(0xFFFCA5A5), width: 1.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                  ],
                  Expanded(
                    child: ElevatedButton.icon(
                      key: const Key('btn_start_voice_navigation'),
                      onPressed: onConfirm,
                      icon: const Icon(Icons.navigation_rounded, size: 20),
                      label: const Text(
                        'Démarrer la navigation vocale',
                        style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size(0, 46),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
