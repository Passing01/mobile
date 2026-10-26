import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/services/map_service.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';

/// Feuille modale présentant la liste des lieux reçus dans la zone visible,
/// triée par distance depuis la position de l'utilisateur ou du centre
class PlacesListBottomSheet extends ConsumerWidget {
  const PlacesListBottomSheet({
    super.key,
    required this.places,
    this.title,
  });

  final List<PlaceModel> places;
  final String? title;

  static void show(BuildContext context, {required List<PlaceModel> places, String? title}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => PlacesListBottomSheet(places: places, title: title),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final location = ref.watch(currentLocationProvider);
    final sortedPlaces = List<PlaceModel>.from(places);
    sortedPlaces.sort((a, b) {
      final distA = a.distanceTo(location.lat, location.lon);
      final distB = b.distanceTo(location.lat, location.lon);
      return distA.compareTo(distB);
    });

    final screenHeight = MediaQuery.of(context).size.height;

    return Container(
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.75,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Poignée de glissement
          Container(
            margin: const EdgeInsets.only(top: 12, bottom: 8),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: const Color(0xFFD1D5DB),
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          // En-tête
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title ?? 'Lieux dans cette zone',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${sortedPlaces.length} lieu${sortedPlaces.length > 1 ? 'x' : ''} trié${sortedPlaces.length > 1 ? 's' : ''} par distance',
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Color(0xFF6B7280)),
                ),
              ],
            ),
          ),

          const Divider(height: 1, color: Color(0xFFE5E7EB)),

          // Liste des lieux
          Flexible(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              itemCount: sortedPlaces.length,
              separatorBuilder: (context, index) => const Divider(
                height: 1,
                color: Color(0xFFF3F4F6),
              ),
              itemBuilder: (context, index) {
                final place = sortedPlaces[index];
                final distMeters = place.distanceTo(location.lat, location.lon);
                final distFormatted = distMeters < 1000
                    ? '${distMeters.round()} m'
                    : '${(distMeters / 1000).toStringAsFixed(1)} km';

                final color = place.categorie?.displayColor ?? const Color(0xFF00A651);

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                      border: Border.all(color: color, width: 2),
                    ),
                    child: Center(
                      child: Icon(
                        place.categorie?.iconData ?? Icons.place_rounded,
                        color: color,
                        size: 20,
                      ),
                    ),
                  ),
                  title: Text(
                    place.nom,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  subtitle: Text(
                    place.quartier ?? place.adresse ?? 'Ouagadougou',
                    style: const TextStyle(
                      fontSize: 13,
                      color: Color(0xFF6B7280),
                    ),
                  ),
                  trailing: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3F4F6),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      distFormatted,
                      style: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF374151),
                      ),
                    ),
                  ),
                  onTap: () {
                    Navigator.of(context).pop();
                    ref.read(selectedPlaceProvider.notifier).select(place);
                    ref.read(mapServiceProvider).animateCamera(
                          lat: place.latitude,
                          lng: place.longitude,
                          zoom: 16.0,
                        );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
