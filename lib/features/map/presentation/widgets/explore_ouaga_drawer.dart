import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class IconicPlaceItem {
  final String title;
  final String subtitle;
  final String badgeText;
  final Color badgeColor;
  final String? distance;
  final double rating;
  final double latitude;
  final double longitude;
  final String gradientStart;
  final String gradientEnd;
  final IconData icon;

  const IconicPlaceItem({
    required this.title,
    required this.subtitle,
    required this.badgeText,
    required this.badgeColor,
    this.distance,
    required this.rating,
    required this.latitude,
    required this.longitude,
    required this.gradientStart,
    required this.gradientEnd,
    required this.icon,
  });
}

/// Tiroir inférieur "Explorer Ouaga & Environs" conforme à la maquette officielle
class ExploreOuagaDrawer extends ConsumerWidget {
  final ValueChanged<IconicPlaceItem> onPlaceTap;
  final VoidCallback? onCollapse;

  const ExploreOuagaDrawer({
    super.key,
    required this.onPlaceTap,
    this.onCollapse,
  });

  static const List<IconicPlaceItem> iconicPlaces = [
    IconicPlaceItem(
      title: 'Héros Nationaux',
      subtitle: 'Ouaga 2000 • Symbole historique',
      badgeText: 'Incontournable',
      badgeColor: Color(0xFF2563EB),
      distance: '2.4 km',
      rating: 4.8,
      latitude: 12.3160,
      longitude: -1.5030,
      gradientStart: '#1E3A8A',
      gradientEnd: '#3B82F6',
      icon: Icons.account_balance_rounded,
    ),
    IconicPlaceItem(
      title: 'Place de la Révolution',
      subtitle: 'Centre-Ville • Cœur historique',
      badgeText: 'Historique',
      badgeColor: Color(0xFFC2410C),
      distance: '1.1 km',
      rating: 4.7,
      latitude: 12.3680,
      longitude: -1.5270,
      gradientStart: '#7C2D12',
      gradientEnd: '#EA580C',
      icon: Icons.flag_rounded,
    ),
    IconicPlaceItem(
      title: 'Grand Marché Rood-Woko',
      subtitle: 'Centre-Ville • Grand pôle commercial',
      badgeText: 'Populaire',
      badgeColor: Color(0xFF0D9488),
      distance: '850 m',
      rating: 4.6,
      latitude: 12.3685,
      longitude: -1.5222,
      gradientStart: '#134E4A',
      gradientEnd: '#14B8A6',
      icon: Icons.storefront_rounded,
    ),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onVerticalDragUpdate: (details) {
        if (details.primaryDelta != null && details.primaryDelta! > 6) {
          onCollapse?.call();
        }
      },
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 40) {
          onCollapse?.call();
        }
      },
      child: Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Colors.black12,
              blurRadius: 20,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            // Poignée de glissement interactive (Descend au swipe / tap)
            Center(
              child: GestureDetector(
                onTap: onCollapse,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                  color: Colors.transparent,
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: const Color(0xFFD1D5DB),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // En-tête : Titre, sous-titre, badge Populaire & bouton réduire
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: const [
                        Text(
                          'Explorer Ouaga & Environs',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF111827),
                          ),
                        ),
                        SizedBox(height: 3),
                        Text(
                          'Patrimoine, verdure et culture burkinabè',
                          style: TextStyle(
                            fontSize: 12,
                            color: Color(0xFF6B7280),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEDE9FE),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'Populaire',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF6D28D9),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'Tout voir',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFF2563EB),
                        ),
                      ),
                      if (onCollapse != null) ...[
                        const SizedBox(width: 4),
                        IconButton(
                          icon: const Icon(Icons.keyboard_arrow_down_rounded,
                              color: Color(0xFF6B7280), size: 26),
                          tooltip: 'Réduire le tiroir',
                          visualDensity: VisualDensity.compact,
                          onPressed: onCollapse,
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

          // Carrousel horizontal de cartes
          SizedBox(
            height: 190,
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              scrollDirection: Axis.horizontal,
              itemCount: iconicPlaces.length,
              separatorBuilder: (context, index) => const SizedBox(width: 14),
              itemBuilder: (context, index) {
                final place = iconicPlaces[index];
                return GestureDetector(
                  onTap: () {
                    onPlaceTap(place);
                  },
                  child: Container(
                    width: 215,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: const Color(0xFFE5E7EB)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Image / Illustration avec Badges
                        Stack(
                          children: [
                            Container(
                              height: 115,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                    top: Radius.circular(18)),
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(int.parse(place.gradientStart.replaceFirst('#', '0xFF'))),
                                    Color(int.parse(place.gradientEnd.replaceFirst('#', '0xFF'))),
                                  ],
                                ),
                              ),
                              child: Center(
                                child: Icon(
                                  place.icon,
                                  size: 48,
                                  color: Colors.white.withValues(alpha: 0.85),
                                ),
                              ),
                            ),
                            // Badge Tag (ex: Incontournable, Historique)
                            Positioned(
                              top: 8,
                              left: 8,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 8, vertical: 3),
                                decoration: BoxDecoration(
                                  color: place.badgeColor,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  place.badgeText,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ),
                            // Distance Badge (ex: 2.4 km)
                            if (place.distance != null)
                              Positioned(
                                bottom: 8,
                                right: 8,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.65),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    place.distance!,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        // Textes & Note
                        Padding(
                          padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Text(
                                      place.title,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF111827),
                                      ),
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  ),
                                  Row(
                                    children: [
                                      const Icon(Icons.star_rounded,
                                          size: 14, color: Color(0xFFF59E0B)),
                                      const SizedBox(width: 2),
                                      Text(
                                        place.rating.toString(),
                                        style: const TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF374151),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                place.subtitle,
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: Color(0xFF6B7280),
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
}
