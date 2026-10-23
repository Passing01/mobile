import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:qvgestion_mobile/core/config/app_config.dart';
import 'package:qvgestion_mobile/core/debug/debug_info.dart';
import 'package:qvgestion_mobile/core/errors/app_error_reporter.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/core/widgets/loaders/app_shimmer.dart';
import 'package:qvgestion_mobile/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:qvgestion_mobile/features/map/presentation/providers/map_state_provider.dart';
import 'package:qvgestion_mobile/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:qvgestion_mobile/features/navigation/presentation/widgets/faso_nav_bottom_bar.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/places/presentation/widgets/places_search_sheet.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';
import 'package:qvgestion_mobile/features/routes/presentation/providers/routes_providers.dart';
import 'package:qvgestion_mobile/features/traffic/presentation/widgets/share_trip_sheet.dart';

/// Onglet 2 officiel : Planification & Calcul d'itinéraires multimodaux
class RoutesScreen extends ConsumerStatefulWidget {
  const RoutesScreen({super.key});

  @override
  ConsumerState<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends ConsumerState<RoutesScreen> {
  late final TextEditingController _originController;
  late final TextEditingController _destController;

  double? _destLat;
  double? _destLon;

  @override
  void initState() {
    super.initState();
    if (AppConfig.testMode) {
      _originController = TextEditingController(text: 'Ouagadougou, 1200 Logements');
      _destController = TextEditingController(text: 'Grand Marché Rood-Woko');
      _destLat = 12.3685;
      _destLon = -1.5222;
      DebugInfo.instance.setDestination(
        const LatLng(12.3685, -1.5222),
        source: 'défaut',
      );
    } else {
      _originController = TextEditingController();
      _destController = TextEditingController();
      _destLat = null;
      _destLon = null;
    }
  }

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    super.dispose();
  }

  void _calculate() {
    if (_destLat == null || _destLon == null) {
      AppErrorReporter.reportError(
        'Veuillez sélectionner ou rechercher une destination pour calculer l\'itinéraire.',
        tag: 'Navigation',
      );
      return;
    }

    final currentLocation = ref.read(currentLocationProvider);
    final selectedMode = ref.read(selectedRouteModeProvider);

    ref.read(activeRouteProvider.notifier).calculate(
          origin: CoordinateModel(
            lat: currentLocation.lat,
            lon: currentLocation.lon,
            name: _originController.text.isNotEmpty ? _originController.text : 'Ma position GPS',
          ),
          destination: CoordinateModel(
            lat: _destLat!,
            lon: _destLon!,
            name: _destController.text.isNotEmpty ? _destController.text : 'Destination',
          ),
          mode: selectedMode,
        );
  }

  @override
  Widget build(BuildContext context) {
    final selectedMode = ref.watch(selectedRouteModeProvider);
    final routeState = ref.watch(activeRouteProvider);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Itinéraires & Navigation',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Carte de saisie Départ / Arrivée
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    const Icon(Icons.my_location_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _originController,
                        decoration: const InputDecoration(
                          labelText: 'Point de départ',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),
                Row(
                  children: [
                    const Icon(Icons.location_on_rounded,
                        color: Color(0xFFDC2626), size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _destController,
                        decoration: InputDecoration(
                          labelText: 'Destination',
                          border: InputBorder.none,
                          isDense: true,
                          suffixIcon: IconButton(
                            icon: const Icon(Icons.search_rounded,
                                color: AppColors.primary, size: 22),
                            tooltip: 'Rechercher un lieu',
                            onPressed: () async {
                              final chosen =
                                  await PlacesSearchSheet.show(context);
                              if (chosen != null) {
                                setState(() {
                                  _destController.text = chosen.nom;
                                  _destLat = chosen.latitude;
                                  _destLon = chosen.longitude;
                                });
                                DebugInfo.instance.setDestination(
                                  LatLng(chosen.latitude, chosen.longitude),
                                  source: 'recherche',
                                );
                                ref
                                    .read(selectedPlaceProvider.notifier)
                                    .select(chosen);
                                final curr = ref.read(currentLocationProvider);
                                ref.read(activeRouteProvider.notifier).calculate(
                                      origin: CoordinateModel(
                                        lat: curr.lat,
                                        lon: curr.lon,
                                        name: _originController.text,
                                      ),
                                      destination: CoordinateModel(
                                        lat: chosen.latitude,
                                        lon: chosen.longitude,
                                        name: chosen.nom,
                                      ),
                                      mode: ref.read(selectedRouteModeProvider),
                                    );
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sélecteur de mode de transport
          Row(
            children: [
              _buildModeChip(
                modeId: 'motorcycle',
                label: 'Moto Urbaine',
                icon: Icons.two_wheeler_rounded,
                isSelected: selectedMode == 'motorcycle',
              ),
              const SizedBox(width: 10),
              _buildModeChip(
                modeId: 'auto',
                label: 'Voiture / Taxi',
                icon: Icons.directions_car_rounded,
                isSelected: selectedMode == 'auto',
              ),
              const SizedBox(width: 10),
              _buildModeChip(
                modeId: 'bicycle',
                label: 'Vélo',
                icon: Icons.pedal_bike_rounded,
                isSelected: selectedMode == 'bicycle',
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bouton Calculer
          ElevatedButton.icon(
            onPressed: _calculate,
            icon: const Icon(Icons.directions_rounded),
            label: const Text('Calculer l\'itinéraire optimal'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Résultats du calcul
          routeState.when(
            data: (route) {
              if (route == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'Appuyez sur "Calculer l\'itinéraire optimal" pour lancer la recherche',
                      style: TextStyle(color: Colors.grey),
                      textAlign: TextAlign.center,
                    ),
                  ),
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFFEFF6FF),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFBFDBFE)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              route.durationFormatted,
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                                color: AppColors.primary,
                              ),
                            ),
                            Text(
                              'Distance : ${route.distanceFormatted} • ${route.engine}',
                              style: const TextStyle(
                                fontSize: 13,
                                color: Color(0xFF1E40AF),
                              ),
                            ),
                          ],
                        ),
                        ElevatedButton.icon(
                          onPressed: () async {
                            final activeLang =
                                ref.read(guidanceLanguageProvider);

                            ref.read(selectedPlaceProvider.notifier).select(
                              PlaceModel(
                                id: 777777,
                                nom: _destController.text,
                                categorieId: 1,
                                latitude: _destLat ??
                                    (route.geometry.isNotEmpty
                                        ? route.geometry.last[0]
                                        : 12.3685),
                                longitude: _destLon ??
                                    (route.geometry.isNotEmpty
                                        ? route.geometry.last[1]
                                        : -1.5222),
                                adresse: _destController.text,
                              ),
                            );

                            await ref
                                .read(activeEnrichedRouteProvider.notifier)
                                .enrichRoute(
                                  route: route,
                                  language: activeLang,
                                );
                            ref
                                .read(currentManeuverIndexProvider.notifier)
                                .reset();
                            ref
                                .read(currentTabProvider.notifier)
                                .selectTab(FasoNavTab.explorer);
                            ref
                                .read(mapScreenStateProvider.notifier)
                                .toActiveNavigation();
                            if (context.mounted) {
                              AppSnackbar.showSuccess(
                                context,
                                title: 'Guidage démarré',
                                message:
                                    'Guidage GPS actif vers ${_destController.text}.',
                              );
                            }
                          },
                          icon: const Icon(Icons.navigation_rounded, size: 18),
                          label: const Text('Démarrer'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        final curr = ref.read(currentLocationProvider);
                        ShareTripSheet.show(
                          context,
                          currentLat: curr.lat,
                          currentLon: curr.lon,
                          initialDestination: _destController.text.trim().isNotEmpty
                              ? _destController.text.trim()
                              : null,
                        );
                      },
                      icon: const Icon(Icons.share_location_rounded, size: 18),
                      label: const Text('Partager mon trajet en direct avec un proche'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Manœuvres pas-à-pas',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF111827),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ...route.maneuvers.map((m) {
                    return ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        backgroundColor: const Color(0xFFF3F4F6),
                        child: Text(
                          m.order.toString(),
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                      title: Text(
                        m.instruction,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      subtitle: Text('${m.distanceMeters.round()} m'),
                    );
                  }),
                ],
              );
            },
            loading: () => const RouteModeShimmer(),
            error: (err, _) => Center(
              child: Text('Erreur: $err', style: const TextStyle(color: Colors.red)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModeChip({
    required String modeId,
    required String label,
    required IconData icon,
    required bool isSelected,
  }) {
    return Expanded(
      child: GestureDetector(
        onTap: () {
          ref.read(selectedRouteModeProvider.notifier).selectMode(modeId);
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primary : Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            children: [
              Icon(
                icon,
                color: isSelected ? Colors.white : const Color(0xFF4B5563),
                size: 20,
              ),
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.bold,
                  color: isSelected ? Colors.white : const Color(0xFF1F2937),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
