import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:qvgestion_mobile/core/config/app_constants.dart';
import 'package:qvgestion_mobile/core/debug/debug_info.dart';
import 'package:qvgestion_mobile/core/errors/app_error_reporter.dart';
import 'package:qvgestion_mobile/core/services/location_service.dart';
import 'package:qvgestion_mobile/core/services/map_service.dart';
import 'package:qvgestion_mobile/core/services/route_service.dart';
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

class WaypointItem {
  final TextEditingController controller;
  CoordinateModel? coord;

  WaypointItem({required this.controller, this.coord});
}

/// Onglet 2 officiel : Planification & Calcul d'itinéraires réels Valhalla (Étape 7)
class RoutesScreen extends ConsumerStatefulWidget {
  const RoutesScreen({super.key});

  @override
  ConsumerState<RoutesScreen> createState() => _RoutesScreenState();
}

class _RoutesScreenState extends ConsumerState<RoutesScreen> {
  late final TextEditingController _originController;
  late final TextEditingController _destController;

  CoordinateModel? _originCoord;
  CoordinateModel? _destCoord;
  final List<WaypointItem> _waypoints = [];

  @override
  void initState() {
    super.initState();
    _originController = TextEditingController();
    _destController = TextEditingController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final locService = ref.read(locationServiceProvider);
      final lastGps = locService.last;
      if (lastGps != null) {
        setState(() {
          _originCoord = CoordinateModel(
            lat: lastGps.latitude,
            lon: lastGps.longitude,
            name: 'Ma position GPS',
          );
          _originController.text = 'Ma position GPS';
        });
      } else {
        final curr = ref.read(currentLocationProvider);
        if (curr.lat != AppConstants.ouagaCenterLatitude || curr.lon != AppConstants.ouagaCenterLongitude) {
          setState(() {
            _originCoord = CoordinateModel(
              lat: curr.lat,
              lon: curr.lon,
              name: curr.label.isNotEmpty ? curr.label : 'Ma position GPS',
            );
            _originController.text = curr.label.isNotEmpty ? curr.label : 'Ma position GPS';
          });
        }
      }

      final selectedPlace = ref.read(selectedPlaceProvider);
      if (selectedPlace != null) {
        setState(() {
          _destController.text = selectedPlace.nom;
          _destCoord = CoordinateModel(
            lat: selectedPlace.latitude,
            lon: selectedPlace.longitude,
            name: selectedPlace.nom,
          );
        });
      }
    });
  }

  @override
  void dispose() {
    _originController.dispose();
    _destController.dispose();
    for (final wp in _waypoints) {
      wp.controller.dispose();
    }
    super.dispose();
  }

  void _addWaypoint() {
    if (_waypoints.length >= 5) {
      AppSnackbar.showInfo(context, message: 'Maximum 5 étapes intermédiaires.');
      return;
    }
    setState(() {
      _waypoints.add(WaypointItem(controller: TextEditingController()));
    });
  }

  void _removeWaypoint(int index) {
    setState(() {
      _waypoints[index].controller.dispose();
      _waypoints.removeAt(index);
    });
  }

  void _calculate() {
    final locService = ref.read(locationServiceProvider);
    final lastGps = locService.last;
    final curr = ref.read(currentLocationProvider);

    final origin = _originCoord ??
        ((lastGps != null)
            ? CoordinateModel(
                lat: lastGps.latitude,
                lon: lastGps.longitude,
                name: 'Ma position GPS',
              )
            : CoordinateModel(
                lat: curr.lat,
                lon: curr.lon,
                name: _originController.text.isNotEmpty
                    ? _originController.text
                    : (curr.label.isNotEmpty ? curr.label : 'Ma position GPS'),
              ));

    if (_destCoord == null) {
      AppErrorReporter.reportError(
        'Veuillez sélectionner ou rechercher une destination pour calculer l\'itinéraire.',
        tag: 'Navigation',
      );
      return;
    }

    final validWaypoints = _waypoints
        .where((w) => w.coord != null)
        .map((w) => w.coord!)
        .toList();

    final selectedMode = ref.read(selectedRouteModeProvider);

    ref.read(activeRouteProvider.notifier).calculate(
          origin: origin,
          destination: _destCoord!,
          waypoints: validWaypoints.isNotEmpty ? validWaypoints : null,
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
          // Bandeau d'erreur explicite en cas d'échec du calcul (Étape 7)
          if (routeState.hasError) ...[
            Container(
              key: const Key('banner_route_error'),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFFEE2E2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: const Color(0xFFEF4444)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded,
                      color: Color(0xFFDC2626), size: 24),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      routeState.error is RoutingException
                          ? (routeState.error as RoutingException).message
                          : routeState.error
                              .toString()
                              .replaceFirst('Exception: ', ''),
                      style: const TextStyle(
                        color: Color(0xFF991B1B),
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Carte de saisie Départ / Étapes / Arrivée
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
                // Point de départ
                Row(
                  children: [
                    const Icon(Icons.my_location_rounded,
                        color: AppColors.primary, size: 20),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        controller: _originController,
                        decoration: const InputDecoration(
                          labelText: 'Point de départ (par défaut: Ma position)',
                          border: InputBorder.none,
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const Divider(height: 16),

                // Étapes intermédiaires (jusqu'à 5)
                for (int i = 0; i < _waypoints.length; i++) ...[
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 10,
                        backgroundColor: const Color(0xFF6366F1),
                        child: Text(
                          '${i + 1}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _waypoints[i].controller,
                          decoration: InputDecoration(
                            labelText: 'Étape ${i + 1}',
                            border: InputBorder.none,
                            isDense: true,
                            suffixIcon: IconButton(
                              icon: const Icon(Icons.search_rounded,
                                  color: AppColors.primary, size: 20),
                              tooltip: 'Rechercher un lieu pour cette étape',
                              onPressed: () async {
                                final chosen =
                                    await PlacesSearchSheet.show(context);
                                if (chosen != null) {
                                  setState(() {
                                    _waypoints[i].controller.text = chosen.nom;
                                    _waypoints[i].coord = CoordinateModel(
                                      lat: chosen.latitude,
                                      lon: chosen.longitude,
                                      name: chosen.nom,
                                    );
                                  });
                                }
                              },
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.remove_circle_outline,
                            color: Colors.redAccent, size: 20),
                        tooltip: 'Supprimer l\'étape',
                        onPressed: () => _removeWaypoint(i),
                      ),
                    ],
                  ),
                  const Divider(height: 16),
                ],

                // Destination finale
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
                                  _destCoord = CoordinateModel(
                                    lat: chosen.latitude,
                                    lon: chosen.longitude,
                                    name: chosen.nom,
                                  );
                                });
                                DebugInfo.instance.setDestination(
                                  LatLng(chosen.latitude, chosen.longitude),
                                  source: 'recherche',
                                );
                                ref
                                    .read(selectedPlaceProvider.notifier)
                                    .select(chosen);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Bouton ajouter une étape (max 5)
                if (_waypoints.length < 5) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: _addWaypoint,
                      icon: const Icon(Icons.add_circle_outline, size: 18),
                      label: Text(
                        'Ajouter une étape (${_waypoints.length}/5)',
                        style: const TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Sélecteur de mode de transport (3 modes officiels : moto, voiture, pied)
          Row(
            children: [
              Expanded(
                child: _buildModeChip(
                  modeId: 'moto',
                  label: 'Moto',
                  icon: Icons.two_wheeler_rounded,
                  isSelected:
                      selectedMode == 'moto' || selectedMode == 'motorcycle',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeChip(
                  modeId: 'voiture',
                  label: 'Voiture',
                  icon: Icons.directions_car_rounded,
                  isSelected: selectedMode == 'voiture' || selectedMode == 'auto',
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildModeChip(
                  modeId: 'pied',
                  label: 'À pied',
                  icon: Icons.directions_walk_rounded,
                  isSelected:
                      selectedMode == 'pied' || selectedMode == 'pedestrian',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Bouton Calculer
          ElevatedButton.icon(
            onPressed: routeState.isLoading ? null : _calculate,
            icon: routeState.isLoading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white),
                  )
                : const Icon(Icons.directions_rounded),
            label: Text(routeState.isLoading
                ? 'Calcul en cours...'
                : 'Calculer l\'itinéraire'),
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
            loading: () => const AppShimmer(
              child: Column(
                children: [
                  AppShimmerBox(width: double.infinity, height: 100, borderRadius: 16),
                  SizedBox(height: 12),
                  AppShimmerBox(width: double.infinity, height: 70, borderRadius: 12),
                  SizedBox(height: 12),
                  AppShimmerBox(width: double.infinity, height: 70, borderRadius: 12),
                ],
              ),
            ),
            error: (err, _) => const SizedBox.shrink(),
            data: (route) {
              if (route == null) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24.0),
                    child: Text(
                      'Appuyez sur "Calculer l\'itinéraire" pour lancer la recherche',
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
                              '${route.distanceFormatted} • ${route.engine}${route.legs > 1 ? " • ${route.legs} tronçons" : ""}',
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
                            final selectedModeNow =
                                ref.read(selectedRouteModeProvider);

                            final destLat = _destCoord?.lat ??
                                (route.geometry.isNotEmpty
                                    ? route.geometry.last[1]
                                    : 0.0);
                            final destLon = _destCoord?.lon ??
                                (route.geometry.isNotEmpty
                                    ? route.geometry.last[0]
                                    : 0.0);

                            final mapService = ref.read(mapServiceProvider);
                            await mapService.clearDestinationPin();
                            await mapService.setTransportMode(selectedModeNow);

                            ref.read(selectedPlaceProvider.notifier).select(
                                  PlaceModel(
                                    id: 777777,
                                    nom: _destController.text.isNotEmpty
                                        ? _destController.text
                                        : (_destCoord?.name ?? 'Destination'),
                                    categorieId: 1,
                                    latitude: destLat,
                                    longitude: destLon,
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
                            minimumSize: const Size(0, 42),
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
                  const SizedBox(height: 16),
                  const Text(
                    'Étapes de guidage (OpenStreetMap)',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1F2937),
                    ),
                  ),
                  const SizedBox(height: 10),
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: route.maneuvers.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final m = route.maneuvers[index];
                      return ListTile(
                        leading: CircleAvatar(
                          backgroundColor: const Color(0xFFF3F4F6),
                          child: Icon(
                            _getManeuverIcon(m.maneuverType),
                            color: AppColors.primary,
                            size: 20,
                          ),
                        ),
                        title: Text(
                          m.instruction,
                          style: const TextStyle(
                              fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                        subtitle: Text(
                          m.streetName ?? 'Voie locale',
                          style:
                              const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                        trailing: Text(
                          m.distanceMeters < 1000
                              ? '${m.distanceMeters.round()} m'
                              : '${(m.distanceMeters / 1000).toStringAsFixed(1)} km',
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      );
                    },
                  ),
                ],
              );
            },
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
    return InkWell(
      onTap: () {
        ref.read(selectedRouteModeProvider.notifier).selectMode(modeId);
        if (_destCoord != null) {
          _calculate();
        }
      },
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE5E7EB),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 18,
              color: isSelected ? Colors.white : Colors.black87,
            ),
            const SizedBox(width: 6),
            Flexible(
              child: Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.black87,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _getManeuverIcon(String type) {
    switch (type.toLowerCase()) {
      case '1':
      case 'straight':
      case 'continue':
        return Icons.arrow_upward_rounded;
      case '10':
      case 'turn_right':
      case 'right':
        return Icons.turn_right_rounded;
      case '15':
      case 'turn_left':
      case 'left':
        return Icons.turn_left_rounded;
      case '26':
      case '27':
      case 'roundabout':
        return Icons.roundabout_right_rounded;
      case '4':
      case '5':
      case 'arrive':
        return Icons.flag_rounded;
      default:
        return Icons.navigation_rounded;
    }
  }
}
