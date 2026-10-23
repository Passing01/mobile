import 'package:flutter/material.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';

enum FasoNavTab {
  explorer,
  itineraires,
  sauvegardes,
  compte,
  admin,
}

/// Barre de navigation inférieure officielle (5 onglets) conforme à la maquette
class FasoNavBottomBar extends StatelessWidget {
  final FasoNavTab currentTab;
  final ValueChanged<FasoNavTab> onTabSelected;
  final bool showAdminTab;

  const FasoNavBottomBar({
    super.key,
    required this.currentTab,
    required this.onTabSelected,
    this.showAdminTab = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        border: const Border(
          top: BorderSide(color: Color(0xFFE5E7EB), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: 60,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                tab: FasoNavTab.explorer,
                label: 'Explorer',
                icon: Icons.explore_outlined,
                activeIcon: Icons.explore_rounded,
              ),
              _buildNavItem(
                tab: FasoNavTab.itineraires,
                label: 'Itinéraires',
                icon: Icons.alt_route_outlined,
                activeIcon: Icons.alt_route_rounded,
              ),
              _buildNavItem(
                tab: FasoNavTab.sauvegardes,
                label: 'Sauvegardés',
                icon: Icons.cloud_download_outlined,
                activeIcon: Icons.cloud_download_rounded,
              ),
              _buildNavItem(
                tab: FasoNavTab.compte,
                label: 'Compte',
                icon: Icons.person_outline_rounded,
                activeIcon: Icons.person_rounded,
              ),
              if (showAdminTab)
                _buildNavItem(
                  tab: FasoNavTab.admin,
                  label: 'Admin',
                  icon: Icons.admin_panel_settings_outlined,
                  activeIcon: Icons.admin_panel_settings_rounded,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required FasoNavTab tab,
    required String label,
    required IconData icon,
    required IconData activeIcon,
  }) {
    final isSelected = tab == currentTab;
    final color = isSelected ? AppColors.primary : const Color(0xFF4B5563);

    return InkWell(
      onTap: () => onTabSelected(tab),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isSelected ? activeIcon : icon,
              color: color,
              size: 24,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
