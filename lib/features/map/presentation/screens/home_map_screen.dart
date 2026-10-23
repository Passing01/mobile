import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:qvgestion_mobile/core/config/app_config.dart';
import 'package:qvgestion_mobile/core/debug/debug_info.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/core/widgets/loaders/app_shimmer.dart';
import 'package:qvgestion_mobile/core/widgets/sheets/active_navigation_card.dart';
import 'package:qvgestion_mobile/core/widgets/sheets/poi_preview_card.dart';
import 'package:qvgestion_mobile/core/widgets/sheets/route_mode_selector_sheet.dart';
import 'package:qvgestion_mobile/features/auth/presentation/providers/auth_notifier.dart';
import 'package:qvgestion_mobile/features/auth/presentation/widgets/auth_modal_sheet.dart';
import 'package:qvgestion_mobile/core/config/env_config.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/explore_ouaga_drawer.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/faso_category_pills.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/faso_nav_header.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/faso_nav_search_bar.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/interactive_faso_map.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/mapbox_faso_map.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/weather_traffic_ticker.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/places/presentation/widgets/places_search_sheet.dart';
import 'package:qvgestion_mobile/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:qvgestion_mobile/features/notifications/presentation/widgets/notifications_sheet.dart';
import 'package:qvgestion_mobile/features/reports/presentation/widgets/report_details_sheet.dart';
import 'package:qvgestion_mobile/features/reports/presentation/widgets/report_incident_modal.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';
import 'package:qvgestion_mobile/features/routes/presentation/providers/routes_providers.dart';
import 'package:qvgestion_mobile/features/map/presentation/providers/map_state_provider.dart';
import 'package:qvgestion_mobile/core/services/voice_guidance_service.dart';
import 'package:qvgestion_mobile/features/places/presentation/widgets/voice_search_sheet.dart';
import 'package:qvgestion_mobile/features/traffic/presentation/widgets/active_tracking_banner.dart';
import 'package:qvgestion_mobile/features/traffic/presentation/widgets/share_trip_sheet.dart';

/// Écran principal Cartographie & Navigation QvGestion / FASO NAV
/// Conforme à la maquette officielle avec carte OpenStreetMap fonctionnelle
class HomeMapScreen extends ConsumerStatefulWidget {
  const HomeMapScreen({super.key});

  @override
  ConsumerState<HomeMapScreen> createState() => _HomeMapScreenState();
}

class _HomeMapScreenState extends ConsumerState<HomeMapScreen> {
  bool _isDrawerCollapsed = false;

  // État de simulation et mouvement du véhicule
  Timer? _simulationTimer;
  int _simulationStep = 0;
  bool _isSimulationPaused = false;
  LatLng? _vehiclePosition;
  double _vehicleHeading = 0.0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authNotifierProvider.notifier).checkAuthStatus();
      ref.read(currentLocationProvider.notifier).fetchRealDeviceLocation();
    });
  }

  @override
  void dispose() {
    _simulationTimer?.cancel();
    super.dispose();
  }

  void _startNavigationSimulation(RouteModel route) {
    if (!AppConfig.testMode) {
      AppLogger.warning(
        'Simulation de navigation ignorée car le mode test est désactivé (Mode réel actif)',
        tag: 'Navigation',
      );
      return;
    }

    _simulationTimer?.cancel();
    _simulationStep = 0;
    _isSimulationPaused = false;

    if (route.geometry.isEmpty || route.geometry[0].length < 2) return;

    _simulationTimer?.cancel();
    _simulationTimer = null;

    final firstPt = LatLng(route.geometry[0][0], route.geometry[0][1]);
    if (mounted) {
      setState(() {
        _vehiclePosition = firstPt;
        _vehicleHeading = 0.0;
      });
    }

    final activeLang = ref.read(guidanceLanguageProvider);
    final firstInstruction = route.maneuvers.isNotEmpty
        ? route.maneuvers.first.instruction
        : 'Suivre l\'itinéraire';
    ref.read(voiceGuidanceServiceProvider).speak(firstInstruction, language: activeLang);

    _simulationTimer = Timer.periodic(const Duration(milliseconds: 1800), (timer) {
      if (_isSimulationPaused) return;

      if (_simulationStep < route.geometry.length - 1) {
        _simulationStep++;
        final prev = route.geometry[_simulationStep - 1];
        final next = route.geometry[_simulationStep];

        if (next.length < 2 || prev.length < 2) return;

        final currentPt = LatLng(next[0], next[1]);
        final heading = _calculateBearing(prev[0], prev[1], next[0], next[1]);

        final lastPt = route.geometry.last;
        final distToArrival = _calculateApproxDistance(next[0], next[1], lastPt[0], lastPt[1]);
        DebugInfo.instance.updateArrivalDistance(distToArrival);

        if (mounted) {
          setState(() {
            _vehiclePosition = currentPt;
            _vehicleHeading = heading;
          });
        }

        final totalSteps = route.maneuvers.length;
        if (totalSteps > 1) {
          final targetIndex = ((_simulationStep / route.geometry.length) * totalSteps).floor();
          if (targetIndex != ref.read(currentManeuverIndexProvider)) {
            final nextStep = targetIndex.clamp(0, totalSteps - 1);
            ref.read(currentManeuverIndexProvider.notifier).setIndex(nextStep);
            final instruction = route.maneuvers[nextStep].instruction;
            final lang = ref.read(guidanceLanguageProvider);
            ref.read(voiceGuidanceServiceProvider).speak(instruction, language: lang);
          }
        }
      } else {
        timer.cancel();
        DebugInfo.instance.updateArrivalDistance(0.0);
        final lang = ref.read(guidanceLanguageProvider);
        ref.read(voiceGuidanceServiceProvider).speak(
          'Vous êtes arrivé à destination ! Trajet complété.',
          language: lang,
        );
        if (mounted) {
          AppSnackbar.showSuccess(
            context,
            title: 'Arrivée à destination',
            message: 'Vous êtes arrivé à bon port ! Trajet complété.',
          );
        }
      }
    });
  }

  double _calculateApproxDistance(double lat1, double lon1, double lat2, double lon2) {
    final dLat = (lat2 - lat1) * 111000.0;
    final dLon = (lon2 - lon1) * 111000.0 * math.cos(lat1 * math.pi / 180.0);
    return math.sqrt(dLat * dLat + dLon * dLon);
  }

  double _calculateBearing(double lat1, double lon1, double lat2, double lon2) {
    if ((lat1 - lat2).abs() < 1e-7 && (lon1 - lon2).abs() < 1e-7) {
      return _vehicleHeading;
    }
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final rLat1 = lat1 * math.pi / 180.0;
    final rLat2 = lat2 * math.pi / 180.0;
    final y = math.sin(dLon) * math.cos(rLat2);
    final x = math.cos(rLat1) * math.sin(rLat2) -
        math.sin(rLat1) * math.cos(rLat2) * math.cos(dLon);
    final rad = math.atan2(y, x);
    final deg = (rad * 180.0 / math.pi + 360.0) % 360.0;
    return deg.isFinite ? deg : 0.0;
  }

  void _stopNavigationSimulation() {
    _simulationTimer?.cancel();
    _simulationTimer = null;
    ref.read(voiceGuidanceServiceProvider).stop();
    if (mounted) {
      setState(() {
        _vehiclePosition = null;
        _isSimulationPaused = false;
        _simulationStep = 0;
      });
    }
  }

  void _startRouteCalculation({
    required PlaceModel destinationPlace,
    required String mode,
  }) {
    ref.read(selectedPlaceProvider.notifier).select(destinationPlace);
    ref.read(selectedRouteModeProvider.notifier).selectMode(mode);

    final currentLocation = ref.read(currentLocationProvider);
    final origin = CoordinateModel(
      lat: currentLocation.lat,
      lon: currentLocation.lon,
      name: currentLocation.label,
    );
    final destination = CoordinateModel(
      lat: destinationPlace.latitude,
      lon: destinationPlace.longitude,
      name: destinationPlace.nom,
    );

    ref.read(activeRouteProvider.notifier).calculate(
          origin: origin,
          destination: destination,
          mode: mode,
        );
    ref.read(mapScreenStateProvider.notifier).toRouteSelection();
  }

  @override
  Widget build(BuildContext context) {
    final screenState = ref.watch(mapScreenStateProvider);
    final selectedPlace = ref.watch(selectedPlaceProvider);
    final activeRouteState = ref.watch(activeRouteProvider);

    ref.listen<MapScreenState>(mapScreenStateProvider, (previous, next) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        if (next == MapScreenState.activeNavigation) {
          final route = ref.read(activeRouteProvider).value;
          if (route != null) {
            _startNavigationSimulation(route);
          }
        } else if (next == MapScreenState.explore) {
          _stopNavigationSimulation();
        }
      });
    });

    return Scaffold(
      body: Stack(
        children: [
          // 1. CARTE INTERACTIVE : Mapbox si jeton renseigné, sinon OpenStreetMap
          if (EnvConfig.mapboxToken.isNotEmpty)
            MapboxFasoMap(
              isNavigating: screenState == MapScreenState.activeNavigation,
              navigationMode: ref.watch(selectedRouteModeProvider),
              navigationPosition: _vehiclePosition,
              vehicleHeading: _vehicleHeading,
              onPlaceSelected: (place) {
                ref.read(selectedPlaceProvider.notifier).select(place);
              },
              onReportSelected: (report) {
                ReportDetailsSheet.show(context, report);
              },
              onReportTap: () {
                ReportIncidentModal.show(context);
              },
              onToggleLayers: () {
                AppSnackbar.showInfo(
                  context,
                  title: 'Calques cartographiques',
                  message: 'Bascule entre vue standard et satellite Mapbox',
                );
              },
            )
          else
            InteractiveFasoMap(
              navigationPosition: _vehiclePosition,
              navigationMode: ref.watch(selectedRouteModeProvider),
              isNavigating: screenState == MapScreenState.activeNavigation,
              vehicleHeading: _vehicleHeading,
              onPlaceSelected: (place) {
                ref.read(selectedPlaceProvider.notifier).select(place);
              },
              onReportSelected: (report) {
                ReportDetailsSheet.show(context, report);
              },
              onReportTap: () {
                ReportIncidentModal.show(context);
              },
              onToggleLayers: () {
                AppSnackbar.showInfo(
                  context,
                  title: 'Calques cartographiques',
                  message: 'Bascule entre vue standard OpenStreetMap et vue satellite',
                );
              },
            ),


          // 2. BANNIÈRE SUPÉRIEURE DE NAVIGATION ACTIVE (Voice Prompt & Commandes)
          if (screenState == MapScreenState.activeNavigation)
            SafeArea(
              child: _buildActiveNavigationTopBar(),
            ),

          // 3. ÉLÉMENTS FLOTTANTS SUPÉRIEURS (FASO NAV Header, Search, Ticker, Category Pills)
          if (screenState != MapScreenState.activeNavigation)
            SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FasoNavHeader(
                    onNotificationsTap: () {
                      NotificationsSheet.show(context);
                    },
                    onShareTripTap: () {
                      final loc = ref.read(currentLocationProvider);
                      ShareTripSheet.show(
                        context,
                        currentLat: loc.lat,
                        currentLon: loc.lon,
                      );
                    },
                    onProfileTap: () {
                      AuthModalSheet.show(context);
                    },
                  ),
                  const ActiveTrackingBanner(),
                  const SizedBox(height: 6),
                  FasoNavSearchBar(
                    onTap: () async {
                      final chosenPlace = await PlacesSearchSheet.show(context);
                      if (chosenPlace != null) {
                        ref.read(selectedPlaceProvider.notifier).select(chosenPlace);
                      }
                    },
                    onVoiceTap: () async {
                      final chosenPlace = await VoiceSearchSheet.show(context);
                      if (chosenPlace != null) {
                        ref.read(selectedPlaceProvider.notifier).select(chosenPlace);
                        if (context.mounted) {
                          AppSnackbar.showInfo(
                            context,
                            title: 'Recherche vocale',
                            message: '📍 ${chosenPlace.nom} localisé sur la carte.',
                          );
                        }
                      }
                    },
                  ),
                  const SizedBox(height: 8),
                  const WeatherTrafficTicker(),
                  const SizedBox(height: 8),
                  const FasoCategoryPills(),
                ],
              ),
            ),

          // 4. TIROIR / FEUILLE INFÉRIEURE CONTEXTUELLE CONFORME À LA MAQUETTE
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _buildBottomContext(
              selectedPlace: selectedPlace,
              activeRouteState: activeRouteState,
              screenState: screenState,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveNavigationTopBar() {
    final currentEnriched = ref.watch(currentEnrichedManeuverProvider);
    final activeLang = ref.watch(guidanceLanguageProvider);
    final selectedMode = ref.watch(selectedRouteModeProvider);

    final instructionText = currentEnriched?.localizedInstruction ?? 'Suivre l\'axe principal';
    final distanceText = currentEnriched?.distanceFormatted ?? '200 m';
    final iconData = currentEnriched?.iconData ?? Icons.navigation_rounded;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(22),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.35),
            blurRadius: 18,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(iconData, color: Colors.white, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Text(
                      distanceText,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        selectedMode.toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  instructionText,
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          if (AppConfig.testMode)
            IconButton(
              onPressed: () {
                setState(() => _isSimulationPaused = !_isSimulationPaused);
              },
              icon: Icon(
                _isSimulationPaused ? Icons.play_arrow_rounded : Icons.pause_rounded,
                color: Colors.white,
                size: 26,
              ),
              tooltip: _isSimulationPaused ? 'Reprendre' : 'Pause',
            ),
          IconButton(
            onPressed: () {
              ref.read(voiceGuidanceServiceProvider).speak(
                    instructionText,
                    language: activeLang,
                  );
              AppSnackbar.showInfo(
                context,
                title: 'Consigne vocale (${activeLang.toUpperCase()})',
                message: '📢 "$instructionText"',
              );
            },
            icon: const Icon(Icons.volume_up_rounded, color: AppColors.primaryLight, size: 24),
            tooltip: 'Répéter la consigne vocale',
          ),
        ],
      ),
    );
  }

  Widget _buildBottomContext({
    required PlaceModel? selectedPlace,
    required AsyncValue<RouteModel?> activeRouteState,
    required MapScreenState screenState,
  }) {
    switch (screenState) {
      case MapScreenState.explore:
        // Si un lieu est cliqué sur la carte ou recherché, afficher sa fiche de prévisualisation
        if (selectedPlace != null) {
          final tags = <String>[
            if (selectedPlace.horaires != null) selectedPlace.horaires!,
            if (selectedPlace.quartier != null) selectedPlace.quartier!,
            if (selectedPlace.telephone != null) selectedPlace.telephone!,
          ];

          return PoiPreviewCard(
            title: selectedPlace.nom,
            category: selectedPlace.categorie?.nom ?? 'Lieu d\'intérêt',
            distance: selectedPlace.formattedDistance ?? 'À proximité',
            status: selectedPlace.horaires ?? 'Ouvert 24h/24',
            culturalLandmark: selectedPlace.quartier != null
                ? 'Quartier ${selectedPlace.quartier}'
                : (selectedPlace.adresse ?? 'Ouagadougou'),
            tags: tags.isNotEmpty ? tags : const ['Accessible deux-roues', 'Ouvert'],
            onNavigateMoto: () {
              _startRouteCalculation(
                destinationPlace: selectedPlace,
                mode: 'motorcycle',
              );
            },
            onNavigateAuto: () {
              _startRouteCalculation(
                destinationPlace: selectedPlace,
                mode: 'auto',
              );
            },
            onNavigateVelo: () {
              _startRouteCalculation(
                destinationPlace: selectedPlace,
                mode: 'bicycle',
              );
            },
            onNavigatePieton: () {
              _startRouteCalculation(
                destinationPlace: selectedPlace,
                mode: 'pedestrian',
              );
            },
            onClose: () {
              ref.read(selectedPlaceProvider.notifier).clear();
            },
          );
        }

        // Si le tiroir est replié, afficher une pastille compacte pour le réouvrir
        if (_isDrawerCollapsed) {
          return _buildCollapsedDrawerPill();
        }

        // Sinon afficher le tiroir officiel "Explorer Ouaga & Environs" avec carrousel
        return ExploreOuagaDrawer(
          onCollapse: () {
            setState(() => _isDrawerCollapsed = true);
          },
          onPlaceTap: (iconic) {
            // Créer ou sélectionner un lieu correspondant
            final place = PlaceModel(
              id: 99,
              nom: iconic.title,
              categorieId: 1,
              latitude: iconic.latitude,
              longitude: iconic.longitude,
              quartier: iconic.subtitle,
              distanceMeters: iconic.distance != null ? 2400.0 : null,
            );
            ref.read(selectedPlaceProvider.notifier).select(place);
          },
        );

      case MapScreenState.routeSelection:
        // Écran 2 : Sélection du mode de transport
        final multiRoutesAsync = ref.watch(multiModeRoutesProvider);
        final selectedMode = ref.watch(selectedRouteModeProvider);
        final currentLocation = ref.watch(currentLocationProvider);

        return multiRoutesAsync.when(
          data: (routes) {
            final motoRoute = routes['motorcycle'];
            final autoRoute = routes['auto'];
            final veloRoute = routes['bicycle'];
            final pietonRoute = routes['pedestrian'];

            final options = [
              RouteModeOption(
                id: 'motorcycle',
                title: 'Moto / Deux-Roues',
                subtitle: motoRoute != null
                    ? 'Pistes prioritaires • ${motoRoute.engine}'
                    : 'Rapide à Ouagadougou',
                duration: motoRoute?.durationFormatted ?? '11 min',
                distance: motoRoute?.distanceFormatted ?? '6.4 km',
                icon: Icons.two_wheeler_rounded,
                isRecommended: true,
              ),
              RouteModeOption(
                id: 'auto',
                title: 'Voiture / Taxi',
                subtitle: autoRoute != null
                    ? 'Itinéraire goudronné • ${autoRoute.engine}'
                    : 'Voies principales',
                duration: autoRoute?.durationFormatted ?? '16 min',
                distance: autoRoute?.distanceFormatted ?? '7.2 km',
                icon: Icons.directions_car_rounded,
              ),
              RouteModeOption(
                id: 'bicycle',
                title: 'Vélo',
                subtitle: veloRoute != null
                    ? 'Pistes secondaires'
                    : 'Voies secondaires',
                duration: veloRoute?.durationFormatted ?? '24 min',
                distance: veloRoute?.distanceFormatted ?? '5.9 km',
                icon: Icons.pedal_bike_rounded,
              ),
              RouteModeOption(
                id: 'pedestrian',
                title: 'Piéton / À pied',
                subtitle: pietonRoute != null
                    ? 'Passages piétons & allées'
                    : 'Trottoirs et allées',
                duration: pietonRoute?.durationFormatted ?? '45 min',
                distance: pietonRoute?.distanceFormatted ?? '4.8 km',
                icon: Icons.directions_walk_rounded,
              ),
            ];

            return RouteModeSelectorSheet(
              originName: currentLocation.label,
              destinationName: selectedPlace?.nom ?? 'Destination',
              options: options,
              selectedModeId: selectedMode,
              onModeSelected: (modeId) {
                ref.read(selectedRouteModeProvider.notifier).selectMode(modeId);
                if (selectedPlace != null) {
                  ref.read(activeRouteProvider.notifier).calculate(
                        origin: CoordinateModel(
                          lat: currentLocation.lat,
                          lon: currentLocation.lon,
                          name: currentLocation.label,
                        ),
                        destination: CoordinateModel(
                          lat: selectedPlace.latitude,
                          lon: selectedPlace.longitude,
                          name: selectedPlace.nom,
                        ),
                        mode: modeId,
                      );
                }
              },
              onBack: () {
                _stopNavigationSimulation();
                ref.read(mapScreenStateProvider.notifier).toExplore();
              },
              onConfirm: () async {
                ref.read(mapScreenStateProvider.notifier).toActiveNavigation();
                final route = ref.read(activeRouteProvider).value;
                final activeLang = ref.read(guidanceLanguageProvider);
                if (route != null) {
                  await ref
                      .read(activeEnrichedRouteProvider.notifier)
                      .enrichRoute(route: route, language: activeLang);
                }
                ref.read(currentManeuverIndexProvider.notifier).reset();
                if (mounted) {
                  AppSnackbar.showSuccess(
                    context,
                    title: 'Guidage démarré',
                    message:
                        'Consignes vocales locales en ${activeLang.toUpperCase()} actives.',
                  );
                }
              },
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(16),
            child: RouteModeShimmer(),
          ),
          error: (err, _) => Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Erreur de calcul d\'itinéraire: $err'),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    ref.invalidate(multiModeRoutesProvider);
                  },
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        );

      case MapScreenState.activeNavigation:
        // Écran 3 : Guidage actif avec consignes locales et repères familiers
        final route = activeRouteState.value;
        final enrichedRoute = ref.watch(activeEnrichedRouteProvider).value;
        final currentEnriched = ref.watch(currentEnrichedManeuverProvider);
        final currentStepIndex = ref.watch(currentManeuverIndexProvider);
        final activeLang = ref.watch(guidanceLanguageProvider);

        final totalSteps = enrichedRoute?.enrichedManeuvers.length ??
            (route?.maneuvers.length ?? 1);
        final currentStep = (currentStepIndex + 1).clamp(1, totalSteps);

        final nextInstruction = currentEnriched?.localizedInstruction ??
            (route?.maneuvers.isNotEmpty == true
                ? route!.maneuvers.first.instruction
                : 'Suivre la voie principale');

        final distanceText = currentEnriched?.distanceFormatted ??
            (route?.maneuvers.isNotEmpty == true
                ? '${route!.maneuvers.first.distanceMeters.round()} m'
                : '300 m');

        final landmarkText = currentEnriched?.hasLandmark == true &&
                currentEnriched?.landmarkName != null
            ? currentEnriched!.landmarkName!
            : (selectedPlace?.quartier != null
                ? 'Quartier ${selectedPlace!.quartier}'
                : 'Axe principal de Ouagadougou');

        return ActiveNavigationCard(
          nextManeuverText: nextInstruction,
          distanceToManeuver: distanceText,
          maneuverIcon: currentEnriched?.iconData ?? Icons.turn_right_rounded,
          culturalLandmark: landmarkText,
          confidence: currentEnriched?.confidence ?? 2,
          remainingTime: enrichedRoute?.totalDurationFormatted ??
              route?.durationFormatted ??
              '9 min',
          remainingDistance: enrichedRoute?.distanceFormatted ??
              route?.distanceFormatted ??
              '4.8 km',
          activeLanguage: activeLang.toUpperCase(),
          currentStep: currentStep,
          totalSteps: totalSteps,
          onLanguageChanged: (newLang) async {
            ref.read(guidanceLanguageProvider.notifier).setLanguage(newLang);
            if (route != null) {
              await ref.read(activeEnrichedRouteProvider.notifier).enrichRoute(
                    route: route,
                    language: newLang,
                  );
              final localized = ref.read(currentEnrichedManeuverProvider)?.localizedInstruction ?? nextInstruction;
              ref.read(voiceGuidanceServiceProvider).speak(localized, language: newLang);
            }
          },
          onNextStep: () {
            ref.read(currentManeuverIndexProvider.notifier).next(totalSteps);
            final nextIdx = ref.read(currentManeuverIndexProvider);
            final inst = (enrichedRoute != null && nextIdx < enrichedRoute.enrichedManeuvers.length)
                ? enrichedRoute.enrichedManeuvers[nextIdx].localizedInstruction
                : (route != null && nextIdx < route.maneuvers.length)
                    ? route.maneuvers[nextIdx].instruction
                    : nextInstruction;
            ref.read(voiceGuidanceServiceProvider).speak(inst, language: activeLang);
          },
          onPreviousStep: () {
            ref.read(currentManeuverIndexProvider.notifier).previous();
            final prevIdx = ref.read(currentManeuverIndexProvider);
            final inst = (enrichedRoute != null && prevIdx < enrichedRoute.enrichedManeuvers.length)
                ? enrichedRoute.enrichedManeuvers[prevIdx].localizedInstruction
                : (route != null && prevIdx < route.maneuvers.length)
                    ? route.maneuvers[prevIdx].instruction
                    : nextInstruction;
            ref.read(voiceGuidanceServiceProvider).speak(inst, language: activeLang);
          },
          onPlayVoice: () {
            ref.read(voiceGuidanceServiceProvider).speak(
                  nextInstruction,
                  language: activeLang,
                );
            final soundId = currentEnriched?.audioSoundId;
            final audioUrl = currentEnriched?.audioUrl;
            AppSnackbar.showInfo(
              context,
              title: 'Consigne vocale (${activeLang.toUpperCase()})',
              message:
                  '📢 "$nextInstruction"${audioUrl != null ? " • Audio: $soundId.wav" : ""}',
            );
          },
          onReportHazard: () {
            ReportIncidentModal.show(context);
          },
          onStopNavigation: () {
            _stopNavigationSimulation();
            ref.read(activeEnrichedRouteProvider.notifier).clear();
            ref.read(currentManeuverIndexProvider.notifier).reset();
            ref.read(mapScreenStateProvider.notifier).toExplore();
            ref.read(activeRouteProvider.notifier).clear();
            AppSnackbar.showInfo(context, message: 'Navigation terminée');
          },
        );
    }
  }

  Widget _buildCollapsedDrawerPill() {
    return Center(
      child: GestureDetector(
        onTap: () => setState(() => _isDrawerCollapsed = false),
        child: Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(30),
            border: Border.all(color: const Color(0xFFE2E8F0)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.18),
                blurRadius: 16,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.explore_rounded, color: AppColors.primary, size: 22),
              SizedBox(width: 10),
              Text(
                'Explorer Ouaga & Environs',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF1E293B),
                ),
              ),
              SizedBox(width: 8),
              Icon(Icons.keyboard_arrow_up_rounded, color: Color(0xFF64748B), size: 22),
            ],
          ),
        ),
      ),
    );
  }
}
