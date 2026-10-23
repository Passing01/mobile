import 'package:flutter/material.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';

/// Carte de suivi de navigation active (Correspondant à l'Écran 3 de la maquette)
/// Intègre le badge de confiance discret du Narrateur v2 (Certifié terrain / Source ouverte / Estimé)
class ActiveNavigationCard extends StatelessWidget {
  final String nextManeuverText;
  final String distanceToManeuver;
  final IconData maneuverIcon;
  final String? culturalLandmark;
  final String remainingTime;
  final String remainingDistance;
  final String activeLanguage;
  final int currentStep;
  final int totalSteps;
  final int confidence; // 3 relevé terrain, 2 déduit d'une source ouverte, 1 incertain
  final VoidCallback onPlayVoice;
  final VoidCallback onReportHazard;
  final VoidCallback onStopNavigation;
  final VoidCallback? onNextStep;
  final VoidCallback? onPreviousStep;
  final ValueChanged<String>? onLanguageChanged;

  const ActiveNavigationCard({
    super.key,
    required this.nextManeuverText,
    required this.distanceToManeuver,
    this.maneuverIcon = Icons.turn_right_rounded,
    this.culturalLandmark,
    required this.remainingTime,
    required this.remainingDistance,
    this.activeLanguage = 'MOS',
    this.currentStep = 1,
    this.totalSteps = 1,
    this.confidence = 2,
    required this.onPlayVoice,
    required this.onReportHazard,
    required this.onStopNavigation,
    this.onNextStep,
    this.onPreviousStep,
    this.onLanguageChanged,
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
            blurRadius: 20,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barre supérieure : Étape courante, Badge de confiance & Sélecteur de langue
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Étape $currentStep / $totalSteps',
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF4B5563),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  _buildConfidenceBadge(confidence),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _LanguageBadge(
                    lang: 'MOS',
                    isSelected: activeLanguage.toUpperCase() == 'MOS',
                    onTap: () => onLanguageChanged?.call('mos'),
                  ),
                  const SizedBox(width: 4),
                  _LanguageBadge(
                    lang: 'DIU',
                    isSelected: activeLanguage.toUpperCase() == 'DIU',
                    onTap: () => onLanguageChanged?.call('diu'),
                  ),
                  const SizedBox(width: 4),
                  _LanguageBadge(
                    lang: 'FR',
                    isSelected: activeLanguage.toUpperCase() == 'FR',
                    onTap: () => onLanguageChanged?.call('fr'),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Prochaine manœuvre & distance
          Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(maneuverIcon, color: Colors.white, size: 30),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      distanceToManeuver,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimaryLight,
                      ),
                    ),
                    Text(
                      nextManeuverText,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondaryLight,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              // Bouton répétition vocale locale
              IconButton.filled(
                onPressed: onPlayVoice,
                icon: const Icon(Icons.volume_up_rounded, size: 22),
                style: IconButton.styleFrom(
                  backgroundColor: AppColors.primaryLight,
                  foregroundColor: AppColors.primary,
                ),
                tooltip: 'Écouter la consigne ($activeLanguage)',
              ),
            ],
          ),

          // Repère visuel burkinabè
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
                  const Icon(Icons.pin_drop_rounded, size: 16, color: AppColors.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      'Repère : $culturalLandmark',
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF374151),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 16),
          const Divider(height: 1, color: Color(0xFFE5E7EB)),
          const SizedBox(height: 12),

          // Métriques temps réel (Durée & Distance restantes) + Signalement & Arrêt
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    remainingTime,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF15803D), // Vert succès
                    ),
                  ),
                  Text(
                    remainingDistance,
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFF6B7280),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Signalement incident
                  IconButton.outlined(
                    onPressed: onReportHazard,
                    icon: const Icon(Icons.warning_amber_rounded, size: 20, color: Color(0xFFD97706)),
                    tooltip: 'Signaler un danger ou nid de poule',
                  ),
                  const SizedBox(width: 8),
                  // Bouton Arrêter navigation
                  Tooltip(
                    message: 'Arrêter la navigation',
                    child: ElevatedButton(
                      onPressed: onStopNavigation,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFDC2626),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.close_rounded, size: 16),
                          SizedBox(width: 4),
                          Text('Quitter', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildConfidenceBadge(int conf) {
    Color bg;
    Color fg;
    String label;
    IconData icon;

    if (conf == 3) {
      bg = const Color(0xFFDCFCE7);
      fg = const Color(0xFF166534);
      label = 'Certifié';
      icon = Icons.verified_rounded;
    } else if (conf == 2) {
      bg = const Color(0xFFDBEAFE);
      fg = const Color(0xFF1E40AF);
      label = 'OpenData';
      icon = Icons.public_rounded;
    } else {
      bg = const Color(0xFFFEF3C7);
      fg = const Color(0xFF92400E);
      label = 'Estimé';
      icon = Icons.info_outline_rounded;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: fg),
          const SizedBox(width: 3),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}

class _LanguageBadge extends StatelessWidget {
  final String lang;
  final bool isSelected;
  final VoidCallback onTap;

  const _LanguageBadge({
    required this.lang,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF3F4F6),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Text(
          lang,
          style: TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: isSelected ? Colors.white : const Color(0xFF6B7280),
          ),
        ),
      ),
    );
  }
}
