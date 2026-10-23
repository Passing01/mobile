import 'package:flutter/material.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';

/// Boutons de contrôle flottants sur la carte (re-centrage GPS, calque trafic, signalement rapide)
class FloatingMapControls extends StatelessWidget {
  final VoidCallback onRecenter;
  final VoidCallback onToggleTraffic;
  final VoidCallback onReportHazard;
  final bool isTrafficActive;

  const FloatingMapControls({
    super.key,
    required this.onRecenter,
    required this.onToggleTraffic,
    required this.onReportHazard,
    this.isTrafficActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Bouton Signalement Danger / Incident (Rouge Faso)
        _buildFabButton(
          icon: Icons.warning_amber_rounded,
          backgroundColor: AppColors.secondary,
          iconColor: Colors.white,
          tooltip: 'Signaler un danger (Nid-de-poule, caniveau, contrôle)',
          onPressed: onReportHazard,
        ),
        const SizedBox(height: 12),
        // Bouton Calque Trafic / Congestion
        _buildFabButton(
          icon: Icons.traffic_rounded,
          backgroundColor: isTrafficActive ? AppColors.accent : Colors.white,
          iconColor: isTrafficActive ? Colors.black87 : AppColors.textPrimaryLight,
          tooltip: 'Afficher le trafic temps réel',
          onPressed: onToggleTraffic,
        ),
        const SizedBox(height: 12),
        // Bouton Re-centrer sur la position actuelle (GPS)
        _buildFabButton(
          icon: Icons.my_location_rounded,
          backgroundColor: Colors.white,
          iconColor: AppColors.primary,
          tooltip: 'Ma position',
          onPressed: onRecenter,
        ),
      ],
    );
  }

  Widget _buildFabButton({
    required IconData icon,
    required Color backgroundColor,
    required Color iconColor,
    required String tooltip,
    required VoidCallback onPressed,
  }) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: backgroundColor,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: Tooltip(
          message: tooltip,
          child: InkWell(
            onTap: onPressed,
            customBorder: const CircleBorder(),
            child: Icon(icon, color: iconColor, size: 22),
          ),
        ),
      ),
    );
  }
}
