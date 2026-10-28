import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:qvgestion_mobile/core/config/app_config.dart';
import 'package:qvgestion_mobile/core/config/app_constants.dart';
import 'package:qvgestion_mobile/core/debug/debug_info.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/core/widgets/loaders/app_shimmer.dart';
import 'package:qvgestion_mobile/core/widgets/sheets/active_navigation_card.dart';
import 'package:qvgestion_mobile/core/widgets/sheets/route_mode_selector_sheet.dart';
import 'package:qvgestion_mobile/features/auth/presentation/providers/auth_notifier.dart';
import 'package:qvgestion_mobile/features/auth/presentation/widgets/auth_modal_sheet.dart';
import 'package:qvgestion_mobile/core/config/map_config.dart';
import 'package:qvgestion_mobile/core/services/map_service.dart';
import 'package:qvgestion_mobile/core/theme/map_theme.dart';
import 'package:qvgestion_mobile/core/theme/theme_provider.dart';
import 'package:qvgestion_mobile/core/widgets/modals/about_credits_modal.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/explore_ouaga_drawer.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/faso_category_pills.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/faso_nav_header.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/faso_nav_search_bar.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/faso_map.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/weather_traffic_ticker.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/places/presentation/widgets/places_search_sheet.dart';
import 'package:qvgestion_mobile/features/guidance/presentation/providers/guidance_providers.dart';
import 'package:qvgestion_mobile/features/notifications/presentation/widgets/notifications_sheet.dart';
import 'package:qvgestion_mobile/features/reports/presentation/widgets/report_incident_modal.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';
import 'package:qvgestion_mobile/features/routes/presentation/providers/routes_providers.dart';
import 'package:qvgestion_mobile/features/map/presentation/providers/map_state_provider.dart';
import 'package:qvgestion_mobile/core/services/voice_guidance_service.dart';
import 'package:qvgestion_mobile/features/places/presentation/widgets/voice_search_sheet.dart';
import 'package:qvgestion_mobile/features/traffic/presentation/widgets/active_tracking_banner.dart';
import 'package:qvgestion_mobile/features/traffic/presentation/widgets/share_trip_sheet.dart';
import 'package:dio/dio.dart';
import 'package:geolocator/geolocator.dart';
import 'package:maplibre_gl/maplibre_gl.dart' as maplibre;
import 'package:qvgestion_mobile/core/services/location_service.dart';
import 'package:qvgestion_mobile/features/places/data/models/category_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/widgets/places_list_bottom_sheet.dart';
import 'package:qvgestion_mobile/core/widgets/sheets/poi_preview_card.dart';
import 'package:qvgestion_mobile/features/places/presentation/widgets/place_detail_sheet.dart';

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

  // État de chargement des lieux par zone visible (Étape 4)
  maplibre.MapLibreMapController? _mapController;
  Timer? _placesDebounce;
  CancelToken? _placesCancelToken;

  // Fiche détaillée du lieu sélectionné (Étape 5)
  String? _activePlaceSheetId;
  PlaceModel? _activeTappedPlace;

  // Suivi GPS et permissions (Étape 6)
  bool _permissionOk = false;
  bool _following = false;
  LocationStatus? _locationStatus;
  StreamSubscription<Position>? _gpsTrackingSub;

  LatLng? get vehiclePosition => _vehiclePosition;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authNotifierProvider.notifier).checkAuthStatus();
      _initLocationService();
      // Téléchargement automatique en arrière-plan des lieux réels OSM pour accès hors-ligne instantané
      ref.read(placesRepositoryProvider).downloadPlacesForOffline([
        'pharmacie',
        'station-service',
        'maquis-restaurant',
        'hopital-sante',
        'banque-distributeur',
        'administration',
        'ecole-universite',
        'marche-commerce',
      ]);
    });
  }

  @override
  void dispose() {
    _gpsTrackingSub?.cancel();
    _simulationTimer?.cancel();
    _placesDebounce?.cancel();
    _placesCancelToken?.cancel();
    super.dispose();
  }

  /// Initialise la demande de permission et démarre le flux GPS souverain (Étape 6)
  Future<void> _initLocationService({bool userInitiated = false}) async {
    final locationService = ref.read(locationServiceProvider);
    final status = await locationService.ensurePermission();
    if (!mounted) return;

    setState(() {
      _locationStatus = status;
      _permissionOk = (status == LocationStatus.ok);
      if (_permissionOk) {
        _following = true;
      }
    });

    if (status == LocationStatus.ok) {
      await locationService.start();
      _gpsTrackingSub?.cancel();
      _gpsTrackingSub = locationService.stream.listen((pos) {
        if (!locationService.isUsable(pos)) return;
        ref.read(currentLocationProvider.notifier).updateLocation(
              pos.latitude,
              pos.longitude,
              'Ma position GPS',
            );
      });

      if (locationService.last != null) {
        final p = locationService.last!;
        ref.read(currentLocationProvider.notifier).updateLocation(
              p.latitude,
              p.longitude,
              'Ma position GPS',
            );
        final c = _mapController ?? ref.read(mapServiceProvider).controller;
        if (c != null && _following) {
          await c.animateCamera(
            maplibre.CameraUpdate.newLatLngZoom(
              maplibre.LatLng(p.latitude, p.longitude),
              16.0,
            ),
          );
        }
      }
    } else if (userInitiated) {
      _showLocationStatusFeedback(status);
    }
  }

  /// Message et actions pour les différents cas d'erreur de permission (Étape 6)
  void _showLocationStatusFeedback(LocationStatus status) {
    final locationService = ref.read(locationServiceProvider);
    switch (status) {
      case LocationStatus.serviceOff:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Service de localisation désactivé. Activez le GPS.'),
            action: SnackBarAction(
              label: 'Activer',
              onPressed: () => locationService.openLocationSettings(),
            ),
          ),
        );
        break;
      case LocationStatus.denied:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Permission de localisation requise pour afficher votre position.'),
            action: SnackBarAction(
              label: 'Autoriser',
              onPressed: () => _initLocationService(userInitiated: true),
            ),
          ),
        );
        break;
      case LocationStatus.deniedForever:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Permission refusée définitivement. Activez-la dans les réglages.'),
            action: SnackBarAction(
              label: 'Réglages',
              onPressed: () => locationService.openAppSettings(),
            ),
          ),
        );
        break;
      case LocationStatus.ok:
        break;
    }
  }

  /// Recentre la carte sur la position GPS réelle et réactive le suivi (Étape 6)
  Future<void> _recenter() async {
    final locationService = ref.read(locationServiceProvider);
    if (!_permissionOk) {
      await _initLocationService(userInitiated: true);
      if (!_permissionOk) return;
    }

    final p = locationService.last;
    if (p == null) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Position inconnue (recherche du signal GPS...)'),
          duration: Duration(seconds: 2),
        ),
      );
      return;
    }

    final c = _mapController ?? ref.read(mapServiceProvider).controller;
    if (c != null) {
      await c.animateCamera(
        maplibre.CameraUpdate.newLatLngZoom(
          maplibre.LatLng(p.latitude, p.longitude),
          16.0,
        ),
      );
      if (mounted) {
        setState(() => _following = true);
        AppLogger.i('[MAP] Suivi caméra réactivé sur la position');
      }
    }
  }

  void _onCameraIdle() {
    _placesDebounce?.cancel();
    _placesDebounce = Timer(const Duration(milliseconds: 350), _refreshPlaces);
  }

  Future<void> _refreshPlaces() async {
    final c = _mapController ?? ref.read(mapServiceProvider).controller;
    if (c == null) return;
    final cats = ref.read(selectedCategoriesProvider);
    final mapService = ref.read(mapServiceProvider);

    _placesCancelToken?.cancel();
      final myToken = CancelToken();
      _placesCancelToken = myToken;

      try {
        final b = await c.getVisibleRegion();
        final bbox = '${b.southwest.longitude},${b.southwest.latitude},${b.northeast.longitude},${b.northeast.latitude}';
        final zoom = c.cameraPosition?.zoom ?? 14.0;

        ref.read(placesStateProvider.notifier).setLoading();

        final repo = ref.read(placesRepositoryProvider);
        final catsParam = cats.isNotEmpty ? cats.toList() : null;
        final data = await repo.getPlacesGeoJson(
          categories: catsParam,
          bbox: bbox,
          zoom: zoom,
          limit: 1000,
        );

        if (_placesCancelToken != myToken) return;

        final features = (data['features'] as List<dynamic>?) ?? [];
        final n = features.length;
        final meta = data['meta'] as Map<String, dynamic>?;
        final truncated = meta?['truncated'] == true;
        final isOffline = data['is_offline'] == true;

        AppLogger.i('[PLACES] categories=${cats.join(',')} bbox=$bbox -> $n lieux (offline=$isOffline)');
        debugPrint('[PLACES] categories=${cats.join(',')} bbox=$bbox -> $n lieux (offline=$isOffline)');
        DebugInfo.instance.setLastApiError(null);

        // Ne pas vider la carte si aucun filtre n'est actif et que la réponse transitoire est vide
        if (n > 0 || cats.isNotEmpty) {
          await mapService.showPlaces(data);
        }

      final placesList = <PlaceModel>[];
      for (final f in features) {
        if (f is Map) {
          try {
            placesList.add(PlaceModel.fromGeoJsonFeature(Map<dynamic, dynamic>.from(f)));
          } catch (_) {}
        }
      }

      String? catLabel;
      final allCats = ref.read(categoriesProvider).value ?? [];
      if (cats.length == 1) {
        final singleSlug = cats.first;
        final foundCat = allCats.cast<CategoryModel?>().firstWhere(
              (cat) => cat?.slug == singleSlug,
              orElse: () => null,
            );
        catLabel = foundCat?.nom ?? singleSlug;
      }

      ref.read(placesStateProvider.notifier).setOk(
        count: n,
        geoJson: data,
        places: placesList,
        categoryLabel: catLabel,
        truncated: truncated,
        isOffline: isOffline,
      );
    } catch (e) {
      final msg = e.toString();
      AppLogger.e('[PLACES] erreur $msg');
      debugPrint('[PLACES] erreur $msg');
      DebugInfo.instance.setLastApiError(msg);
      ref.read(placesStateProvider.notifier).setError(msg);
    }
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

  void _cancelRouteAndNavigation() {
    _stopNavigationSimulation();
    final mapService = ref.read(mapServiceProvider);
    mapService.clearRoute();
    mapService.clearDestinationPin();
    mapService.clearHighlight();
    mapService.setTransportMode(null);
    ref.read(activeEnrichedRouteProvider.notifier).clear();
    ref.read(currentManeuverIndexProvider.notifier).reset();
    ref.read(activeRouteProvider.notifier).clear();
    ref.read(selectedPlaceProvider.notifier).clear();
    if (mounted) {
      setState(() {
        _activePlaceSheetId = null;
        _activeTappedPlace = null;
      });
    }
    ref.read(mapScreenStateProvider.notifier).toExplore();
  }

  void _startRouteCalculation({
    required PlaceModel destinationPlace,
    required String mode,
    String source = 'lieu touché',
  }) {
    AppLogger.i('Démarrage itinéraire vers ${destinationPlace.nom} (source: $source, mode: $mode)');
    debugPrint('Démarrage itinéraire vers ${destinationPlace.nom} (source: $source, mode: $mode)');
    DebugInfo.instance.setDestination(
      LatLng(destinationPlace.latitude, destinationPlace.longitude),
      source: source,
    );

    final mapService = ref.read(mapServiceProvider);
    if (source != 'appui long') {
      mapService.clearDestinationPin();
    }
    mapService.clearHighlight();
    mapService.setTransportMode(mode);

    if (mounted) {
      setState(() {
        _activePlaceSheetId = null;
        _activeTappedPlace = null;
        // Désactiver le verrouillage caméra pour laisser l'utilisateur explorer le tracé librement (comme Google Maps / Waze)
        _following = false;
      });
    }

    ref.read(selectedPlaceProvider.notifier).select(destinationPlace);
    ref.read(selectedRouteModeProvider.notifier).selectMode(mode);

    final locService = ref.read(locationServiceProvider);
    final lastGps = locService.last;
    final currentLocation = ref.read(currentLocationProvider);

    final double originLat;
    final double originLon;
    final String originName;

    if (lastGps != null) {
      originLat = lastGps.latitude;
      originLon = lastGps.longitude;
      originName = 'Ma position GPS';
    } else {
      originLat = currentLocation.lat;
      originLon = currentLocation.lon;
      originName = currentLocation.label;
    }

    final origin = CoordinateModel(
      lat: originLat,
      lon: originLon,
      name: originName,
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

  void _closePlaceSheet() {
    setState(() {
      _activePlaceSheetId = null;
      _activeTappedPlace = null;
    });
    ref.read(selectedPlaceProvider.notifier).clear();
    final mapService = ref.read(mapServiceProvider);
    mapService.clearHighlight();
  }

  PlaceModel? _findClosestPlaceInMemory(maplibre.LatLng geo, {double maxDistanceM = 45.0}) {
    final places = ref.read(placesStateProvider).placesList;
    if (places.isEmpty) return null;
    PlaceModel? closest;
    double bestDist = maxDistanceM;
    for (final pl in places) {
      final d = _calculateApproxDistance(geo.latitude, geo.longitude, pl.latitude, pl.longitude);
      if (d <= bestDist) {
        bestDist = d;
        closest = pl;
      }
    }
    return closest;
  }

  Map<String, dynamic> _closestTarget(List<Map<String, dynamic>> feats, maplibre.LatLng geo) {
    Map<String, dynamic>? best;
    double minDistance = double.infinity;
    int maxImportance = -1;

    for (final feat in feats) {
      final geom = feat['geometry'];
      if (geom is Map) {
        final coords = geom['coordinates'];
        if (coords is List && coords.length >= 2) {
          final lon = (coords[0] as num).toDouble();
          final lat = (coords[1] as num).toDouble();
          final dLat = lat - geo.latitude;
          final dLon = lon - geo.longitude;
          final dist = dLat * dLat + dLon * dLon;

          final props = feat['properties'] is Map ? feat['properties'] as Map : {};
          final importance = (props['importance'] as num?)?.toInt() ?? 3;

          // Le plus proche du doigt, à égalité le plus important
          if (dist < minDistance - 1e-9) {
            minDistance = dist;
            maxImportance = importance;
            best = feat;
          } else if ((dist - minDistance).abs() <= 1e-9 && importance > maxImportance) {
            maxImportance = importance;
            best = feat;
          }
        }
      }
    }
    return best ?? feats.first;
  }

  Future<void> _handleMapTap(math.Point<double> p, maplibre.LatLng geo) async {
    final mapService = ref.read(mapServiceProvider);
    final feats = await mapService.queryTapFeatures(p);
    AppLogger.i('[TAP] ${geo.latitude},${geo.longitude} -> ${feats.length} élément(s)');
    debugPrint('[TAP] ${geo.latitude},${geo.longitude} -> ${feats.length} élément(s)');

    if (feats.isEmpty) {
      final memoryMatch = _findClosestPlaceInMemory(geo, maxDistanceM: 42.0);
      if (memoryMatch != null) {
        final memId = memoryMatch.uuid ?? memoryMatch.id.toString();
        AppLogger.i('[TAP] lieu trouvé en mémoire proche : ${memoryMatch.nom} (id: $memId)');
        await mapService.highlightFeature(memoryMatch.toGeoJsonFeature());
        setState(() {
          _activePlaceSheetId = memId;
          _activeTappedPlace = memoryMatch;
        });
        return;
      }
      // 5. Vide touché : ne rien faire, mais écrire une ligne de journal
      // Plus aucune « Destination sur la carte » n'apparaît après un simple toucher
      return;
    }

    // 2. Vérifier si une grappe est touchée
    Map<String, dynamic>? cluster;
    for (final f in feats) {
      if ((f['properties'] as Map?)?['point_count'] != null) {
        cluster = f;
        break;
      }
    }
    if (cluster != null) {
      // 3. Grappe touchée : zoomer de deux niveaux, centré sur la grappe
      await mapService.zoomIn(geo, delta: 2.0);
      final z = mapService.controller?.cameraPosition?.zoom ?? 12.5;
      AppLogger.i('[TAP] grappe -> zoom ${(z + 2.0).toStringAsFixed(1)}');
      debugPrint('[TAP] grappe -> zoom ${(z + 2.0).toStringAsFixed(1)}');
      return;
    }

    // 2. Choisir la bonne cible : point le plus proche du doigt, à égalité le plus important
    final best = _closestTarget(feats, geo);
    final props = best['properties'] as Map?;
    final id = props?['id']?.toString() ?? props?['uuid']?.toString();

    if (id == null) {
      AppLogger.e('[TAP] lieu sans id : $props');
      debugPrint('[TAP] lieu sans id : $props');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Lieu sans identifiant'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      return;
    }

    AppLogger.i('[TAP] lieu sélectionné : ${props?['name'] ?? props?['nom']} (id: $id)');
    debugPrint('[TAP] lieu sélectionné : ${props?['name'] ?? props?['nom']} (id: $id)');

    PlaceModel? tappedPlace;
    try {
      tappedPlace = PlaceModel.fromGeoJsonFeature(best);
    } catch (_) {}

    // 4. Lieu touché : mettre un halo autour du point, puis ouvrir la fiche
    await mapService.highlightFeature(best);
    setState(() {
      _activePlaceSheetId = id;
      _activeTappedPlace = tappedPlace;
    });
  }

  Future<void> _handleMapLongPress(math.Point<double> p, maplibre.LatLng geo) async {
    AppLogger.i('[LONG_PRESS] ${geo.latitude},${geo.longitude}');
    debugPrint('[LONG_PRESS] ${geo.latitude},${geo.longitude}');

    final mapService = ref.read(mapServiceProvider);

    // Vérifier si l'appui long a été fait directement sur un lieu nommé (ex: école, pharmacie)
    PlaceModel? nearbyNamedPlace = _findClosestPlaceInMemory(geo, maxDistanceM: 45.0);
    if (nearbyNamedPlace == null) {
      final feats = await mapService.queryTapFeatures(p);
      for (final f in feats) {
        if ((f['properties'] as Map?)?['point_count'] == null) {
          try {
            nearbyNamedPlace = PlaceModel.fromGeoJsonFeature(f);
            break;
          } catch (_) {}
        }
      }
    }

    // 6. Appui long : poser une épingle « Destination » et demander confirmation (« Aller ici ? »)
    await mapService.dropDestinationPin(geo);

    if (!mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: const [
            Icon(Icons.place_rounded, color: Color(0xFFDC2626), size: 26),
            SizedBox(width: 8),
            Text(
              'Destination',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Aller ici ?',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Color(0xFF0F172A)),
            ),
            if (nearbyNamedPlace != null) ...[
              const SizedBox(height: 4),
              Text(
                nearbyNamedPlace.nom,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF0F766E)),
              ),
            ],
            const SizedBox(height: 6),
            Text(
              'Coordonnées : ${geo.latitude.toStringAsFixed(5)}, ${geo.longitude.toStringAsFixed(5)}',
              style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
            ),
          ],
        ),
        actions: [
          TextButton(
            key: const Key('btn_cancel_destination'),
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler', style: TextStyle(color: Color(0xFF64748B))),
          ),
          ElevatedButton(
            key: const Key('btn_confirm_destination'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF0F766E),
              foregroundColor: Colors.white,
              minimumSize: const Size(0, 40),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Aller ici', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      if (nearbyNamedPlace != null) {
        await mapService.clearDestinationPin();
        _startRouteCalculation(
          destinationPlace: nearbyNamedPlace,
          mode: 'motorcycle',
          source: 'lieu touché',
        );
      } else {
        // Démarre l'itinéraire avec source: 'appui long'
        final destPlace = PlaceModel(
          id: DateTime.now().millisecondsSinceEpoch,
          nom: 'Destination choisie',
          categorieId: 0,
          latitude: geo.latitude,
          longitude: geo.longitude,
          quartier: 'Ouagadougou',
          adresse: '${geo.latitude.toStringAsFixed(4)}, ${geo.longitude.toStringAsFixed(4)}',
        );
        _startRouteCalculation(
          destinationPlace: destPlace,
          mode: 'motorcycle',
          source: 'appui long',
        );
      }
    } else {
      // Refuser la retire
      await mapService.clearDestinationPin();
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenState = ref.watch(mapScreenStateProvider);
    final selectedPlace = ref.watch(selectedPlaceProvider);
    final activeRouteState = ref.watch(activeRouteProvider);
    final mapConfigAsync = ref.watch(mapConfigProvider);
    final mapService = ref.watch(mapServiceProvider);

    // Synchronisation de l'itinéraire actif vers MapService
    ref.listen(activeRouteProvider, (prev, next) {
      final route = next.value;
      if (route != null) {
        mapService.setRoute(route);
      } else {
        mapService.clearRoute();
      }
    });

    // Synchronisation lieu sélectionné vers MapService (dépose le pin)
    ref.listen(selectedPlaceProvider, (prev, next) {
      mapService.setSelectedPlace(next);
      if (next != null && ref.read(mapScreenStateProvider) == MapScreenState.explore) {
        mapService.animateCamera(lat: next.latitude, lng: next.longitude, zoom: 15.5);
      }
    });

    // Synchronisation position GPS vers MapService (dépose le repère de position)
    ref.listen(currentLocationProvider, (prev, next) {
      mapService.updateUserLocation(next.lat, next.lon);
      if (prev == null ||
          (prev.lat == AppConstants.ouagaCenterLatitude &&
              prev.lon == AppConstants.ouagaCenterLongitude &&
              (next.lat != AppConstants.ouagaCenterLatitude ||
                  next.lon != AppConstants.ouagaCenterLongitude))) {
        mapService.animateCamera(lat: next.lat, lng: next.lon, zoom: 15.5);
        _refreshPlaces();
      }
    });

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

    // Synchronisation de l'état des catégories vers le chargeur de lieux
    ref.listen<Set<String>>(selectedCategoriesProvider, (previous, next) {
      _refreshPlaces();
    });

    final isSatellite = ref.watch(isSatelliteModeProvider);
    final themeMode = ref.watch(themeModeProvider);
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final isDark = themeMode == ThemeMode.dark ||
        (themeMode == ThemeMode.system && platformBrightness == Brightness.dark);
    final mapTheme = isSatellite
        ? MapTheme.satellite
        : (isDark ? MapTheme.dark : MapTheme.light);

    final styleUrl = isSatellite
        ? (mapConfigAsync.value?.styleSatellite ?? MapConfig.defaultFasoSatellite)
        : (isDark
            ? (mapConfigAsync.value?.styleDark ?? MapConfig.defaultFasoDark)
            : (mapConfigAsync.value?.styleLight ?? MapConfig.defaultFasoLight));
    final attributionText = isSatellite
        ? '© OpenStreetMap contributors, © Esri'
        : (mapConfigAsync.value?.attribution ?? MapConfig.defaultAttribution);

    final placesState = ref.watch(placesStateProvider);
    final selectedCats = ref.watch(selectedCategoriesProvider);
    final gpsLost = ref.watch(gpsLostProvider);

    return Scaffold(
      body: Stack(
        children: [
          // 1. CARTE INTERACTIVE UNIFIÉE : MapLibre Native + OpenStreetMap
          FasoMap(
            key: const Key('faso_map_widget'),
            styleUrl: styleUrl,
            attributionText: attributionText,
            myLocationEnabled: _permissionOk,
            myLocationTrackingMode: _following
                ? maplibre.MyLocationTrackingMode.tracking
                : maplibre.MyLocationTrackingMode.none,
            onCameraTrackingDismissed: () {
              if (mounted && _following) {
                setState(() => _following = false);
                AppLogger.i('[MAP] Suivi caméra désactivé par déplacement manuel');
              }
            },
            onCameraIdle: _onCameraIdle,
            onStyleReady: (controller) async {
              _mapController = controller;
              mapService.attach(controller);
              await mapService.setupLayers(theme: mapTheme);
              final loc = ref.read(currentLocationProvider);
              await mapService.updateUserLocation(loc.lat, loc.lon);
              final selPlace = ref.read(selectedPlaceProvider);
              if (selPlace != null) {
                await mapService.setSelectedPlace(selPlace);
              }
              final lastGeoJson = ref.read(placesStateProvider).lastGeoJson;
              if ((lastGeoJson['features'] as List?)?.isNotEmpty == true) {
                await mapService.showPlaces(lastGeoJson);
              }
              final route = ref.read(activeRouteProvider).value;
              if (route != null) {
                await mapService.setRoute(route);
              }
              await _refreshPlaces();
            },
            onTap: (point, latLng) async {
              await _handleMapTap(point, latLng);
            },
            onLongPress: (point, latLng) async {
              await _handleMapLongPress(point, latLng);
            },
            onAttributionTap: () {
              AboutCreditsModal.show(context);
            },
          ),

          // 1.1 BADGE FLOTTANT "Hors-ligne prêt" ou "Mode hors-ligne" dynamique
          if (screenState != MapScreenState.activeNavigation)
            Positioned(
              left: 20,
              bottom: 300,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: placesState.isOffline ? const Color(0xFF0F172A) : Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: placesState.isOffline ? const Color(0xFF38BDF8) : const Color(0xFFE5E7EB),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      placesState.isOffline ? Icons.cloud_off_rounded : Icons.check_circle_rounded,
                      color: placesState.isOffline ? const Color(0xFF38BDF8) : const Color(0xFF22C55E),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      placesState.isOffline
                          ? 'Hors-ligne (${placesState.count} lieux)'
                          : 'Hors-ligne prêt',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: placesState.isOffline ? Colors.white : const Color(0xFF374151),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // 1.2 CONTRÔLES FLOTTANTS CARTE (Signalement, Centrage GPS)
          if (screenState != MapScreenState.activeNavigation)
            Positioned(
              right: 16,
              bottom: 270,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    key: const Key('fab_report_hazard'),
                    onTap: () => ReportIncidentModal.show(context),
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFFCA5A5), width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFDC2626).withValues(alpha: 0.2),
                            blurRadius: 10,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.campaign_rounded,
                        color: Color(0xFFDC2626),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Bouton bascule Mode Satellite
                  GestureDetector(
                    key: const Key('fab_toggle_satellite'),
                    onTap: () {
                      ref.read(isSatelliteModeProvider.notifier).toggle();
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: isSatellite ? AppColors.primary : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSatellite ? AppColors.primary : const Color(0xFFE5E7EB),
                          width: 1.5,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        Icons.satellite_alt_rounded,
                        color: isSatellite ? Colors.white : const Color(0xFF4B5563),
                        size: 22,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Bouton bascule Mode Plein Soleil / Nuit
                  GestureDetector(
                    key: const Key('fab_toggle_theme'),
                    onTap: () {
                      ref.read(themeModeProvider.notifier).toggle();
                    },
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                        color: isDark ? const Color(0xFFF59E0B) : const Color(0xFF4B5563),
                        size: 24,
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  GestureDetector(
                    key: const Key('fab_recenter'),
                    onTap: _recenter,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        color: _following ? AppColors.primary : Colors.white,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _following ? AppColors.primary : const Color(0xFFE5E7EB),
                          width: _following ? 2 : 1,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Icon(
                        _following ? Icons.gps_fixed_rounded : Icons.my_location_rounded,
                        color: _following ? Colors.white : AppColors.primary,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // 2. BANNIÈRE SUPÉRIEURE DE NAVIGATION ACTIVE (Voice Prompt & Commandes)
          if (screenState == MapScreenState.activeNavigation)
            SafeArea(
              child: _buildActiveNavigationTopBar(),
            ),

          // 2.1 BANNIÈRE COMPACTE D'APERÇU D'ITINÉRAIRE (Écran 2 : laisse la carte grande ouverte)
          if (screenState == MapScreenState.routeSelection)
            SafeArea(
              child: _buildRoutePreviewTopBar(selectedPlace),
            ),

          // 3. ÉLÉMENTS FLOTTANTS SUPÉRIEURS (FASO NAV Header, Search, Ticker, Category Pills)
          if (screenState == MapScreenState.explore)
            SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Bandeau officiel MODE TEST bien visible (Tâche 11)
                  if (AppConfig.testMode)
                    Container(
                      key: const Key('banner_test_mode'),
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                      color: const Color(0xFFEA580C),
                      child: const Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.science_rounded, size: 16, color: Colors.white),
                          SizedBox(width: 6),
                          Text(
                            'MODE TEST ACTIF',
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Bandeau Signal GPS perdu (Étape 6) : apparaît si aucun point depuis >10s
                  if (gpsLost && _permissionOk)
                    Container(
                      key: const Key('banner_gps_lost'),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: const Row(
                        children: [
                          Icon(Icons.gps_off_rounded, color: Colors.white, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Signal GPS perdu',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(Colors.white70),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Bandeaux de statut de permission GPS (Étape 6)
                  if (_locationStatus == LocationStatus.serviceOff)
                    _buildGpsStatusBanner(
                      key: const Key('banner_gps_service_off'),
                      icon: Icons.location_disabled_rounded,
                      message: 'Service de localisation désactivé',
                      actionLabel: 'Activer',
                      onAction: () => ref.read(locationServiceProvider).openLocationSettings(),
                    ),
                  if (_locationStatus == LocationStatus.denied)
                    _buildGpsStatusBanner(
                      key: const Key('banner_gps_denied'),
                      icon: Icons.location_searching_rounded,
                      message: 'Permission de localisation requise',
                      actionLabel: 'Autoriser',
                      onAction: () => _initLocationService(userInitiated: true),
                    ),
                  if (_locationStatus == LocationStatus.deniedForever)
                    _buildGpsStatusBanner(
                      key: const Key('banner_gps_denied_forever'),
                      icon: Icons.settings_suggest_rounded,
                      message: 'Permission refusée dans les réglages',
                      actionLabel: 'Réglages',
                      onAction: () => ref.read(locationServiceProvider).openAppSettings(),
                    ),

                  // Bandeau rouge d'erreur réseau avec conservation des points (Tâche 9)
                  if (placesState.hasError)
                    Container(
                      key: const Key('banner_api_error'),
                      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFDC2626),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              placesState.errorMessage ?? 'Erreur réseau (points précédents conservés)',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          TextButton(
                            onPressed: _refreshPlaces,
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: const Text(
                              'Réessayer',
                              style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                            ),
                          ),
                        ],
                      ),
                    ),

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

                  // Compteur dynamique et bouton Liste triée par distance (Tâche 10)
                  if (selectedCats.isNotEmpty && placesState.count > 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                      child: Row(
                        children: [
                          Container(
                            key: const Key('badge_places_count'),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(color: const Color(0xFFE5E7EB)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.08),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF00A651),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  '${placesState.count} ${placesState.categoryLabel != null ? (placesState.count > 1 ? '${placesState.categoryLabel}s' : placesState.categoryLabel) : (placesState.count > 1 ? 'lieux' : 'lieu')}${placesState.truncated ? ' (tronqué)' : ''}',
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1F2937),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton.icon(
                            key: const Key('btn_places_list'),
                            onPressed: () {
                              PlacesListBottomSheet.show(
                                context,
                                places: placesState.placesList,
                                title: placesState.categoryLabel != null
                                    ? '${placesState.categoryLabel}s dans la zone'
                                    : 'Lieux dans la zone',
                              );
                            },
                            icon: const Icon(Icons.format_list_bulleted_rounded, size: 16),
                            label: const Text('Liste', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF1E3A5F),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              minimumSize: Size.zero,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                              elevation: 2,
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Message ZÉRO LIEU avec bouton "Voir toute la ville" (Tâche 9)
                  if (selectedCats.isNotEmpty && placesState.isZero && !placesState.isLoading)
                    Padding(
                      padding: const EdgeInsets.only(top: 8, left: 16, right: 16),
                      child: Container(
                        key: const Key('banner_zero_places'),
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEF3C7),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: const Color(0xFFFDE68A)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.06),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline_rounded, color: Color(0xFFB45309), size: 18),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Aucun lieu dans cette zone',
                                style: TextStyle(
                                  color: Color(0xFF92400E),
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            ElevatedButton(
                              key: const Key('btn_view_entire_city'),
                              onPressed: () {
                                ref.read(mapServiceProvider).animateCamera(
                                  lat: AppConstants.ouagaCenterLatitude,
                                  lng: AppConstants.ouagaCenterLongitude,
                                  zoom: 12.5,
                                );
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFD97706),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                minimumSize: Size.zero,
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                elevation: 0,
                              ),
                              child: const Text('Voir toute la ville', style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                      ),
                    ),
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

  Widget _buildGpsStatusBanner({
    required Key key,
    required IconData icon,
    required String message,
    required String actionLabel,
    required VoidCallback onAction,
  }) {
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFB45309), // Ambre soutenu
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.15),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 12,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }

  IconData _modeIconData(String mode) {
    final m = mode.toLowerCase();
    if (m == 'pied' || m == 'pedestrian') return Icons.directions_walk_rounded;
    if (m == 'voiture' || m == 'auto') return Icons.directions_car_rounded;
    if (m == 'velo' || m == 'bicycle') return Icons.pedal_bike_rounded;
    return Icons.two_wheeler_rounded;
  }

  String _modeLabelFr(String mode) {
    final m = mode.toLowerCase();
    if (m == 'pied' || m == 'pedestrian') return 'À PIED';
    if (m == 'voiture' || m == 'auto') return 'VOITURE';
    if (m == 'velo' || m == 'bicycle') return 'VÉLO';
    return 'MOTO';
  }

  Widget _buildRoutePreviewTopBar(PlaceModel? selectedPlace) {
    final selectedMode = ref.watch(selectedRouteModeProvider);
    final activeRoute = ref.watch(activeRouteProvider).value;
    final destName = selectedPlace?.nom ?? 'Destination';

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 14,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _modeIconData(selectedMode),
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: const Color(0xFF16A34A),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _modeLabelFr(selectedMode),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    if (activeRoute != null) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${activeRoute.durationFormatted} • ${activeRoute.distanceFormatted}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  'Vers $destName',
                  style: const TextStyle(
                    color: Color(0xFFE2E8F0),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          IconButton(
            key: const Key('btn_top_cancel_route'),
            onPressed: _cancelRouteAndNavigation,
            icon: const Icon(Icons.close_rounded, color: Colors.white, size: 22),
            tooltip: 'Annuler l\'itinéraire',
            visualDensity: VisualDensity.compact,
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
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(_modeIconData(selectedMode), color: Colors.white, size: 12),
                          const SizedBox(width: 4),
                          Text(
                            _modeLabelFr(selectedMode),
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
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
          IconButton(
            key: const Key('btn_top_stop_navigation'),
            onPressed: () {
              _cancelRouteAndNavigation();
              AppSnackbar.showInfo(context, message: 'Navigation terminée');
            },
            icon: const Icon(Icons.close_rounded, color: Color(0xFFF87171), size: 24),
            tooltip: 'Quitter l\'itinéraire',
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
        // 1. Si un lieu est cliqué sur la carte (Étape 5) : Fiche détaillée PlaceDetailSheet
        if (_activePlaceSheetId != null) {
          return PlaceDetailSheet(
            placeId: _activePlaceSheetId!,
            initialPlace: _activeTappedPlace,
            onClose: _closePlaceSheet,
            onNavigate: (place, source) {
              _startRouteCalculation(
                destinationPlace: place,
                mode: 'motorcycle',
                source: source,
              );
            },
            onReport: () {
              ReportIncidentModal.show(context);
            },
          );
        }

        // 2. Si un lieu est sélectionné depuis le tiroir ou la recherche : fiche PoiPreviewCard
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
                source: 'lieu sélectionné',
              );
            },
            onNavigateAuto: () {
              _startRouteCalculation(
                destinationPlace: selectedPlace,
                mode: 'auto',
                source: 'lieu sélectionné',
              );
            },
            onNavigateVelo: () {
              _startRouteCalculation(
                destinationPlace: selectedPlace,
                mode: 'bicycle',
                source: 'lieu sélectionné',
              );
            },
            onNavigatePieton: () {
              _startRouteCalculation(
                destinationPlace: selectedPlace,
                mode: 'pedestrian',
                source: 'lieu sélectionné',
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
            final motoRoute = routes['motorcycle'] ?? routes['moto'];
            final autoRoute = routes['auto'] ?? routes['voiture'];
            final veloRoute = routes['bicycle'] ?? routes['velo'] ?? routes['pied'];
            final pietonRoute = routes['pedestrian'] ?? routes['pied'];

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
                ref.read(mapServiceProvider).setTransportMode(modeId);
                final precalculated = routes[modeId];
                if (precalculated != null) {
                  ref.read(activeRouteProvider.notifier).setRoute(precalculated);
                } else if (selectedPlace != null) {
                  final locService = ref.read(locationServiceProvider);
                  final lastGps = locService.last;
                  final origin = (lastGps != null)
                      ? CoordinateModel(
                          lat: lastGps.latitude,
                          lon: lastGps.longitude,
                          name: 'Ma position GPS',
                        )
                      : CoordinateModel(
                          lat: currentLocation.lat,
                          lon: currentLocation.lon,
                          name: currentLocation.label,
                        );
                  ref.read(activeRouteProvider.notifier).calculate(
                        origin: origin,
                        destination: CoordinateModel(
                          lat: selectedPlace.latitude,
                          lon: selectedPlace.longitude,
                          name: selectedPlace.nom,
                        ),
                        mode: modeId,
                      );
                }
              },
              onBack: _cancelRouteAndNavigation,
              onConfirm: () async {
                final selectedModeNow = ref.read(selectedRouteModeProvider);
                ref.read(mapServiceProvider).setTransportMode(selectedModeNow);
                ref.read(mapScreenStateProvider.notifier).toActiveNavigation();
                final locService = ref.read(locationServiceProvider);
                final p = locService.last;
                if (p != null) {
                  setState(() => _following = true);
                  ref.read(mapServiceProvider).animateCamera(
                        lat: p.latitude,
                        lng: p.longitude,
                        zoom: 17.0,
                      );
                }
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

        final rawSteps = (enrichedRoute?.enrichedManeuvers.isNotEmpty == true)
            ? enrichedRoute!.enrichedManeuvers.length
            : (route?.maneuvers.isNotEmpty == true ? route!.maneuvers.length : 1);
        final totalSteps = rawSteps < 1 ? 1 : rawSteps;
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
            _cancelRouteAndNavigation();
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
