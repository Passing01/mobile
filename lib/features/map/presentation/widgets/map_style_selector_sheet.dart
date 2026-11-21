import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/theme/theme_provider.dart';

/// Feuille de sélection du fond de carte FASO NAV :
/// Clair, Sombre, Satellite ou Faso 3D Immersif (+ option Vue Radar Live en guidage).
class MapStyleSelectorSheet extends ConsumerWidget {
  const MapStyleSelectorSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (_) => const MapStyleSelectorSheet(),
    );
  }

  MapStyleMode _currentMode(WidgetRef ref, BuildContext context) {
    final is3d = ref.watch(is3dMapModeProvider);
    if (is3d) return MapStyleMode.faso3d;

    final isSat = ref.watch(isSatelliteModeProvider);
    if (isSat) return MapStyleMode.satellite;

    final themeMode = ref.watch(themeModeProvider);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system &&
            MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    return isDark ? MapStyleMode.dark : MapStyleMode.light;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = _currentMode(ref, context);
    final isRadarEnabled = ref.watch(isRadarViewEnabledProvider);
    final navViewMode = ref.watch(navigationViewModeProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 24,
            offset: Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 42,
                height: 5,
                decoration: BoxDecoration(
                  color: const Color(0xFFD1D5DB),
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                const Icon(Icons.layers_rounded, color: AppColors.primary, size: 22),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Choisir le type de carte',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF111827),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 4),
            const Text(
              'Basculez entre la carte standard, satellite ou le nouveau mode 3D du Burkina Faso.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF6B7280)),
            ),
            const SizedBox(height: 16),
            GridView.count(
              crossAxisCount: 2,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 12,
              crossAxisSpacing: 12,
              childAspectRatio: 1.48,
              children: [
                _StyleOptionCard(
                  key: const Key('map_style_option_light'),
                  title: 'Faso Clair',
                  subtitle: 'Lisible plein soleil',
                  icon: Icons.wb_sunny_rounded,
                  accentColor: const Color(0xFF1A73E8),
                  gradient: const [Color(0xFFF6F2E9), Color(0xFFE7EFE4)],
                  isSelected: current == MapStyleMode.light,
                  onTap: () {
                    selectMapStyleMode(ref, MapStyleMode.light);
                    Navigator.of(context).pop();
                  },
                ),
                _StyleOptionCard(
                  key: const Key('map_style_option_dark'),
                  title: 'Faso Nuit',
                  subtitle: 'Conduite nocturne',
                  icon: Icons.nightlight_round,
                  accentColor: const Color(0xFF5AA2FF),
                  gradient: const [Color(0xFF0F172A), Color(0xFF1E293B)],
                  isDarkPreview: true,
                  isSelected: current == MapStyleMode.dark,
                  onTap: () {
                    selectMapStyleMode(ref, MapStyleMode.dark);
                    Navigator.of(context).pop();
                  },
                ),
                _StyleOptionCard(
                  key: const Key('map_style_option_satellite'),
                  title: 'Satellite HD',
                  subtitle: 'Imagerie aérienne',
                  icon: Icons.satellite_alt_rounded,
                  accentColor: const Color(0xFF00B4D8),
                  gradient: const [Color(0xFF1B4332), Color(0xFF2D6A4F)],
                  isDarkPreview: true,
                  isSelected: current == MapStyleMode.satellite,
                  onTap: () {
                    selectMapStyleMode(ref, MapStyleMode.satellite);
                    Navigator.of(context).pop();
                  },
                ),
                _StyleOptionCard(
                  key: const Key('map_style_option_3d'),
                  title: 'Faso 3D',
                  subtitle: 'Bâtiments & Monuments',
                  badge: 'NOUVEAU',
                  icon: Icons.view_in_ar_rounded,
                  accentColor: const Color(0xFFD97706),
                  gradient: const [Color(0xFFFFF3E0), Color(0xFFFDE68A)],
                  isSelected: current == MapStyleMode.faso3d,
                  onTap: () {
                    selectMapStyleMode(ref, MapStyleMode.faso3d);
                    Navigator.of(context).pop();
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            // Interrupteur Vue Radar Live (style voiture autonome)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF0F172A),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: isRadarEnabled ? const Color(0xFF38BDF8) : const Color(0xFF1E293B),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.radar_rounded,
                      color: Color(0xFF38BDF8),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Vue Radar Live en itinéraire',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 2),
                        Text(
                          'Optionnel : sinon navigation immergée entre les bâtiments 3D',
                          style: TextStyle(
                            color: Color(0xFF94A3B8),
                            fontSize: 11.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Switch.adaptive(
                    key: const Key('switch_radar_view_mode'),
                    value: isRadarEnabled,
                    activeTrackColor: const Color(0xFF0284C7),
                    activeThumbColor: const Color(0xFF38BDF8),
                    onChanged: (val) {
                      ref.read(isRadarViewEnabledProvider.notifier).setEnabled(val);
                    },
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Entre bâtiments 3D'),
                    selected: !isRadarEnabled && navViewMode == NavigationViewMode.buildings3d,
                    onSelected: (_) {
                      selectNavigationViewMode(ref, NavigationViewMode.buildings3d);
                      selectMapStyleMode(ref, MapStyleMode.faso3d);
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Text('Vue Carte standard'),
                    selected: !isRadarEnabled && navViewMode == NavigationViewMode.mapTop,
                    onSelected: (_) {
                      selectNavigationViewMode(ref, NavigationViewMode.mapTop);
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StyleOptionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? badge;
  final IconData icon;
  final Color accentColor;
  final List<Color> gradient;
  final bool isDarkPreview;
  final bool isSelected;
  final VoidCallback onTap;

  const _StyleOptionCard({
    super.key,
    required this.title,
    required this.subtitle,
    this.badge,
    required this.icon,
    required this.accentColor,
    required this.gradient,
    this.isDarkPreview = false,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = isDarkPreview ? Colors.white : const Color(0xFF111827);
    final subColor = isDarkPreview ? const Color(0xFFCBD5E1) : const Color(0xFF4B5563);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradient,
          ),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isSelected ? accentColor : const Color(0xFFE5E7EB),
            width: isSelected ? 2.5 : 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: accentColor.withValues(alpha: 0.22),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: accentColor.withValues(alpha: isDarkPreview ? 0.25 : 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(icon, color: accentColor, size: 20),
                ),
                if (badge != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                    decoration: BoxDecoration(
                      color: accentColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      badge!,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.4,
                      ),
                    ),
                  )
                else if (isSelected)
                  Icon(Icons.check_circle_rounded, color: accentColor, size: 20),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: textColor,
                  ),
                ),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 11,
                    color: subColor,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

