import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart' as ll;
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart' as mb;
import 'package:permission_handler/permission_handler.dart';
import 'package:turf/turf.dart' as turf;
import 'package:qvgestion_mobile/core/config/app_config.dart';
import 'package:qvgestion_mobile/core/config/app_constants.dart';
import 'package:qvgestion_mobile/core/config/env_config.dart';
import 'package:qvgestion_mobile/core/debug/debug_info.dart';
import 'package:qvgestion_mobile/core/errors/app_error_reporter.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/navigation/presentation/providers/navigation_providers.dart';
import 'package:qvgestion_mobile/features/navigation/presentation/widgets/faso_nav_bottom_bar.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/reports/data/models/report_model.dart';
import 'package:qvgestion_mobile/features/routes/presentation/providers/routes_providers.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/places_layer.dart';

/// Carte interactive officielle propulsée par Mapbox Maps Flutter
/// Conforme au guide technique QvGestion 2026
enum MapboxMapStyle {
  streets(
    'Plan des Rues',
    mb.MapboxStyles.MAPBOX_STREETS,
    Icons.map_rounded,
    'Rues détaillées, goudrons et pistes urbaines',
  ),
  satellite(
    'Satellite HD',
    mb.MapboxStyles.SATELLITE_STREETS,
    Icons.satellite_alt_rounded,
    'Vue aérienne haute définition avec superposition des axes',
  ),
  outdoors(
    'Plein Air & Relief',
    mb.MapboxStyles.OUTDOORS,
    Icons.terrain_rounded,
    'Relief topographique, pistes et espaces naturels',
  ),
  dark(
    'Mode Nuit (Dark)',
    mb.MapboxStyles.DARK,
    Icons.dark_mode_rounded,
    'Navigation sombre optimisée pour la conduite nocturne',
  );

  final String label;
  final String uri;
  final IconData icon;
  final String description;

  const MapboxMapStyle(this.label, this.uri, this.icon, this.description);
}

class MapboxFasoMap extends ConsumerStatefulWidget {
  final ValueChanged<PlaceModel> onPlaceSelected;
  final ValueChanged<ReportModel>? onReportSelected;
  final VoidCallback? onReportTap;
  final VoidCallback? onToggleLayers;
  final bool isNavigating;
  final String navigationMode;
  final ll.LatLng? navigationPosition;
  final double vehicleHeading;

  const MapboxFasoMap({
    super.key,
    required this.onPlaceSelected,
    this.onReportSelected,
    this.onReportTap,
    this.onToggleLayers,
    this.isNavigating = false,
    this.navigationMode = 'motorcycle',
    this.navigationPosition,
    this.vehicleHeading = 0.0,
  });

  @override
  ConsumerState<MapboxFasoMap> createState() => _MapboxFasoMapState();
}

class _MapboxFasoMapState extends ConsumerState<MapboxFasoMap> {
  mb.MapboxMap? _mapboxMap;
  mb.PointAnnotationManager? _pointAnnotationManager;
  mb.PolylineAnnotationManager? _polylineAnnotationManager;
  MapboxMapStyle _currentStyle = MapboxMapStyle.streets;
  final Map<String, PlaceModel> _placesByAnnotationId = {};
  bool _isSyncingRoute = false;
  PlacesLayer? _placesLayer;
  PlacesController? _placesController;

  @override
  void dispose() {
    _placesController?.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(covariant MapboxFasoMap oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Suivi de navigation temps réel : caméra orientée et inclinée
    if (widget.isNavigating && widget.navigationPosition != null) {
      final lat = widget.navigationPosition!.latitude;
      final lon = widget.navigationPosition!.longitude;
      if (lat.isFinite && lon.isFinite) {
        final heading = widget.vehicleHeading.isFinite
            ? (widget.vehicleHeading % 360.0)
            : 0.0;
        try {
          _mapboxMap?.setCamera(
            mb.CameraOptions(
              center: turf.Point(
                coordinates: turf.Position(lon, lat),
              ),
              bearing: heading,
              pitch: 45.0,
              zoom: 16.5,
            ),
          );
        } catch (e) {
          AppLogger.d('Erreur animation caméra véhicule: $e');
        }
      }
    }
  }

  void _onMapCreated(mb.MapboxMap map) async {
    _mapboxMap = map;
    final currentLocation = ref.read(currentLocationProvider);

    try {
      // Positionne la caméra initiale sur la position courante ou Ouagadougou
      await map.setCamera(
        mb.CameraOptions(
          center: turf.Point(
            coordinates: turf.Position(
              currentLocation.lon,
              currentLocation.lat,
            ),
          ),
          zoom: 14.5,
        ),
      );

      // Gestionnaires d'annotations sécurisés
      _pointAnnotationManager =
          await map.annotations.createPointAnnotationManager();
      _polylineAnnotationManager =
          await map.annotations.createPolylineAnnotationManager();

      // Écoute les clics sur les marqueurs
      _pointAnnotationManager?.tapEvents(
        onTap: (annotation) {
          final place = _placesByAnnotationId[annotation.id];
          if (place != null) {
            widget.onPlaceSelected(place);
            flyTo(place.latitude, place.longitude, zoom: 15.5);
          }
        },
      );

      // Active le point bleu pulsant et orienté
      await _enableLocationComponent();

      // Trace l'itinéraire actif s'il existe déjà
      await _syncActiveRoute();

      // Charge les marqueurs des lieux mis en avant
      await _refreshMarkers();

      // Initialise la couche clusterisée officielle PlacesLayer
      _placesLayer = PlacesLayer(map);
      await _placesLayer?.setup();

      _placesController = PlacesController(
        map: map,
        layer: _placesLayer!,
        repository: ref.read(placesRepositoryProvider),
        onPlaceSelected: (place) {
          widget.onPlaceSelected(place);
          flyTo(place.latitude, place.longitude, zoom: 15.5);
        },
      );
      _placesController?.setCategories(ref.read(selectedCategoriesProvider));
    } catch (e) {
      AppLogger.w('Initialisation Mapbox: $e');
    }
  }

  Future<void> _enableLocationComponent() async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      var status = await Permission.locationWhenInUse.status;
      if (!status.isGranted) {
        status = await Permission.locationWhenInUse.request();
      }

      if (status.isGranted) {
        await map.location.updateSettings(
          mb.LocationComponentSettings(
            enabled: true,
            pulsingEnabled: true,
            puckBearingEnabled: true,
          ),
        );
      }
    } catch (e) {
      AppLogger.d('Erreur activation puck localisation: $e');
    }
  }

  Future<void> _refreshMarkers() async {
    final manager = _pointAnnotationManager;
    if (manager == null) return;

    try {
      await manager.deleteAll();
      _placesByAnnotationId.clear();

      final places = ref.read(nearbyPlacesProvider).value ?? [];
      final selectedSlug = ref.read(selectedCategorySlugProvider);
      final selectedCats = ref.read(selectedCategoriesProvider);

      bool matchesCategory(PlaceModel place) {
        if (selectedCats.isEmpty && selectedSlug == null) return true;
        final pSlug = (place.categorie?.slug ?? '').toLowerCase();
        final pNom = place.nom.toLowerCase();

        for (final cat in selectedCats) {
          final c = cat.toLowerCase();
          if (pSlug == c || pSlug.contains(c)) {
            return true;
          }
          if (c == 'pharmacie' && (pSlug.contains('pharmacie') || pNom.contains('pharmacie'))) {
            return true;
          }
          if ((c == 'station-service' || c == 'station') &&
              (pSlug.contains('station') || pNom.contains('station') || pNom.contains('total') || pNom.contains('shell') || pNom.contains('oil'))) {
            return true;
          }
          if ((c == 'maquis-restaurant' || c == 'maquis') &&
              (pSlug.contains('maquis') || pSlug.contains('restaurant') || pNom.contains('maquis') || pNom.contains('restaurant'))) {
            return true;
          }
          if ((c == 'hopital' || c == 'sante') &&
              (pSlug.contains('hopital') || pNom.contains('chuy') || pNom.contains('yalgado') || pNom.contains('clinique') || pNom.contains('cma'))) {
            return true;
          }
          if (c == 'administration' &&
              (pSlug.contains('admin') || pNom.contains('mairie') || pNom.contains('commissariat') || pNom.contains('minist'))) {
            return true;
          }
        }

        if (selectedSlug != null) {
          final s = selectedSlug.toLowerCase();
          if (pSlug == s || pSlug.contains(s)) {
            return true;
          }
          if (s == 'pharmacie' && (pSlug.contains('pharmacie') || pNom.contains('pharmacie'))) {
            return true;
          }
          if ((s == 'station-service' || s == 'station') &&
              (pSlug.contains('station') || pNom.contains('station') || pNom.contains('total') || pNom.contains('shell'))) {
            return true;
          }
        }

        return false;
      }

      final candidatePlaces = [
        ...places,
        if (AppConfig.testMode) ...defaultOuagaIconicPlaces,
      ];

      final filteredPlaces = (selectedCats.isNotEmpty || selectedSlug != null)
          ? candidatePlaces.where(matchesCategory).toList()
          : candidatePlaces;

      final seenIds = <int>{};
      for (final place in filteredPlaces) {
        if (seenIds.contains(place.id)) continue;
        seenIds.add(place.id);

        String prefix = '📍 ';
        final slug = place.categorie?.slug ?? '';
        final nomLower = place.nom.toLowerCase();

        if (slug == 'pharmacie' || nomLower.contains('pharmacie')) {
          prefix = '💊 ';
        } else if (slug == 'station-service' || nomLower.contains('station') || nomLower.contains('total') || nomLower.contains('shell')) {
          prefix = '⛽ ';
        } else if (slug == 'maquis-restaurant' || nomLower.contains('maquis') || nomLower.contains('restaurant')) {
          prefix = '🍽️ ';
        } else if (slug == 'hopital' || nomLower.contains('hopital') || nomLower.contains('chuy') || nomLower.contains('clinique')) {
          prefix = '🏥 ';
        } else if (nomLower.contains('héros') || nomLower.contains('monument')) {
          prefix = '🏛️ ';
        } else if (nomLower.contains('révolution') || nomLower.contains('place')) {
          prefix = '⭐ ';
        } else if (nomLower.contains('marché')) {
          prefix = '🏪 ';
        }

        final opt = mb.PointAnnotationOptions(
          geometry: turf.Point(
            coordinates: turf.Position(place.longitude, place.latitude),
          ),
          textField: '$prefix${place.nom}',
          textOffset: [0.0, 1.2],
          textSize: 12.0,
          textColor: 0xFF0F172A,
          textHaloColor: 0xFFFFFFFF,
          textHaloWidth: 2.2,
          iconSize: 1.0,
        );

        final created = await manager.create(opt);
        _placesByAnnotationId[created.id] = place;
      }
    } catch (e) {
      AppLogger.w('Rafraîchissement des marqueurs: $e');
    }
  }

  /// Tracé ultra-sécurisé de l'itinéraire actif via PolylineAnnotationManager
  Future<void> _syncActiveRoute() async {
    if (!mounted) return;
    try {
      final currentTab = ref.read(currentTabProvider);
      if (currentTab != FasoNavTab.explorer) return;
    } catch (e) {
      AppLogger.d('Erreur lecture onglet: $e');
    }

    final manager = _polylineAnnotationManager;
    if (manager == null || _isSyncingRoute) return;
    _isSyncingRoute = true;

    try {
      final activeRoute = ref.read(activeRouteProvider).value;
      try {
        await manager.deleteAll();
      } catch (e) {
        AppLogger.d('Suppression ancienne ligne tracé: $e');
      }

      if (activeRoute != null && activeRoute.geometry.length >= 2) {
        final lineCoords = <turf.Position>[];
        turf.Position? lastPos;

        for (final pt in activeRoute.geometry) {
          if (pt.length >= 2 && pt[0].isFinite && pt[1].isFinite) {
            final lat = pt[0].toDouble();
            final lon = pt[1].toDouble();
            if (lastPos == null ||
                (lastPos.lat - lat).abs() > 1e-6 ||
                (lastPos.lng - lon).abs() > 1e-6) {
              final pos = turf.Position(lon, lat);
              lineCoords.add(pos);
              lastPos = pos;
            }
          }
        }

        if (lineCoords.length >= 2 && mounted) {
          try {
            await manager.create(
              mb.PolylineAnnotationOptions(
                geometry: turf.LineString(coordinates: lineCoords),
                lineColor: 0xFF2563EB, // Bleu dynamique FASO NAV
                lineWidth: 6.5,
              ),
            );
          } catch (e) {
            AppLogger.w('Création annotation polyline Mapbox: $e');
          }

          // Ajuster la caméra pour afficher l'ensemble de l'itinéraire tracé
          if (activeRoute.boundingBox.length >= 4 && mounted) {
            final minLat = activeRoute.boundingBox[0];
            final minLon = activeRoute.boundingBox[1];
            final maxLat = activeRoute.boundingBox[2];
            final maxLon = activeRoute.boundingBox[3];
            if (minLat.isFinite && maxLat.isFinite && minLon.isFinite && maxLon.isFinite) {
              final centerLat = (minLat + maxLat) / 2;
              final centerLon = (minLon + maxLon) / 2;
              await flyTo(centerLat, centerLon, zoom: 13.5);
            }
          }
        }
      }
    } catch (e) {
      AppLogger.w('Tracé d\'itinéraire Mapbox: $e');
    } finally {
      _isSyncingRoute = false;
    }
  }

  /// Déplace la caméra de manière fluide vers une position
  Future<void> flyTo(double lat, double lng, {double zoom = 15.5}) async {
    if (!mounted) return;
    final map = _mapboxMap;
    if (map == null || !lat.isFinite || !lng.isFinite) return;

    try {
      await map.flyTo(
        mb.CameraOptions(
          center: turf.Point(coordinates: turf.Position(lng, lat)),
          zoom: zoom.clamp(3.0, 20.0),
        ),
        mb.MapAnimationOptions(duration: 900),
      );
    } catch (e) {
      AppLogger.w('flyTo Mapbox: $e');
    }
  }

  /// Change dynamiquement le style graphique Mapbox
  Future<void> _selectStyle(MapboxMapStyle newStyle) async {
    final map = _mapboxMap;
    if (map == null || _currentStyle == newStyle) return;

    setState(() {
      _currentStyle = newStyle;
    });

    try {
      await map.loadStyleURI(newStyle.uri);

      // Réinitialiser les gestionnaires d'annotations sur le nouveau style chargé
      _pointAnnotationManager =
          await map.annotations.createPointAnnotationManager();
      _polylineAnnotationManager =
          await map.annotations.createPolylineAnnotationManager();

      _pointAnnotationManager?.tapEvents(
        onTap: (annotation) {
          final place = _placesByAnnotationId[annotation.id];
          if (place != null) {
            widget.onPlaceSelected(place);
          }
        },
      );

      await _enableLocationComponent();
      await _placesLayer?.setup();
      await _placesController?.refresh();
      await _refreshMarkers();
      await _syncActiveRoute();
    } catch (e) {
      AppLogger.w('Changement de style Mapbox: $e');
    }
  }

  /// Modal ergonomique de sélection des 4 styles cartographiques officiels Mapbox
  void _showMapStyleModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 44,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Styles cartographiques Mapbox',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Choisissez l\'affichage adapté à votre navigation à Ouagadougou',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.textSecondaryLight,
                    ),
                  ),
                  const SizedBox(height: 16),
                  ...MapboxMapStyle.values.map((style) {
                    final isSelected = style == _currentStyle;
                    return InkWell(
                      onTap: () {
                        Navigator.of(ctx).pop();
                        _selectStyle(style);
                      },
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 10),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary.withValues(alpha: 0.08)
                              : const Color(0xFFF9FAFB),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? AppColors.primary
                                : const Color(0xFFE5E7EB),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 44,
                              height: 44,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? AppColors.primary
                                    : const Color(0xFFE5E7EB),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(
                                style.icon,
                                color: isSelected ? Colors.white : Colors.black87,
                                size: 22,
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    style.label,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: isSelected
                                          ? AppColors.primary
                                          : AppColors.textPrimaryLight,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    style.description,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected)
                              const Icon(
                                Icons.check_circle_rounded,
                                color: AppColors.primary,
                                size: 22,
                              ),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _handleRecenter() async {
    await _enableLocationComponent();
    await ref.read(currentLocationProvider.notifier).fetchRealDeviceLocation();
    final currentLocation = ref.read(currentLocationProvider);
    await flyTo(currentLocation.lat, currentLocation.lon, zoom: 16.5);
  }

  /// Gestion des clics sur la surface de la carte pour définir une destination
  Future<void> _onMapTapped(Offset localPosition) async {
    final map = _mapboxMap;
    if (map == null) return;

    try {
      final screenCoord = mb.ScreenCoordinate(x: localPosition.dx, y: localPosition.dy);
      // D'abord interroger PlacesController (points et clusters)
      final handled = await _placesController?.handleTap(screenCoord) ?? false;
      if (handled) return;

      final point = await map.coordinateForPixel(screenCoord);

      final coordinates = point.coordinates;
      final lon = (coordinates[0] as num).toDouble();
      final lat = (coordinates[1] as num).toDouble();

      // Vérifier si un lieu connu est à proximité immédiate du toucher (~75 m)
      PlaceModel? closestPlace;
      double minDistance = double.infinity;
      final candidates = [
        ..._placesByAnnotationId.values,
        ...(ref.read(nearbyPlacesProvider).value ??
            (AppConfig.testMode ? defaultOuagaIconicPlaces : <PlaceModel>[])),
      ];
      for (final place in candidates) {
        final dLat = (place.latitude - lat).abs();
        final dLon = (place.longitude - lon).abs();
        final approxDistMeters = (dLat + dLon) * 111000.0 * 0.72;
        if (approxDistMeters < 75.0 && approxDistMeters < minDistance) {
          minDistance = approxDistMeters;
          closestPlace = place;
        }
      }

      if (closestPlace != null) {
        DebugInfo.instance.setDestination(
          ll.LatLng(closestPlace.latitude, closestPlace.longitude),
          source: 'lieu touché',
        );
        widget.onPlaceSelected(closestPlace);
        flyTo(closestPlace.latitude, closestPlace.longitude, zoom: 16.0);
        return;
      }

      final customPlace = PlaceModel(
        id: 888888,
        nom: 'Destination sur la carte',
        categorieId: 1,
        latitude: lat,
        longitude: lon,
        adresse:
            'Ouagadougou (${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)})',
        quartier: 'Ouagadougou',
      );

      DebugInfo.instance.setDestination(
        ll.LatLng(lat, lon),
        source: 'lieu touché',
      );
      widget.onPlaceSelected(customPlace);
    } catch (e, st) {
      AppErrorReporter.reportError(
        'Erreur lors de la sélection sur la carte',
        error: e,
        stackTrace: st,
        tag: 'MapTouch',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Écoute les nouveaux lieux reçus du backend
    ref.listen(nearbyPlacesProvider, (prev, next) {
      if (next.hasValue) {
        _refreshMarkers();
      }
    });

    // Écoute le changement de catégorie (ex: clic sur "Pharmacies de garde")
    ref.listen(selectedCategorySlugProvider, (prev, next) {
      _refreshMarkers();
    });

    // Écoute le multi-filtrage de catégories FASO NAV (PlacesLayer)
    ref.listen(selectedCategoriesProvider, (prev, next) {
      _placesController?.setCategories(next);
      _refreshMarkers();
    });

    // Écoute la sélection d'un lieu pour centrer immédiatement la caméra
    ref.listen(selectedPlaceProvider, (prev, next) {
      if (next != null) {
        flyTo(next.latitude, next.longitude, zoom: 16.0);
      }
    });

    // Écoute la mise à jour de l'itinéraire actif pour le tracé
    ref.listen(activeRouteProvider, (prev, next) {
      _syncActiveRoute();
    });

    // Écoute le retour sur l'onglet Explorer pour mettre à jour l'itinéraire en toute sécurité
    ref.listen(currentTabProvider, (prev, next) {
      if (next == FasoNavTab.explorer) {
        _syncActiveRoute();
      }
    });

    // Écoute l'obtention de la position GPS pour rediriger automatiquement la caméra
    ref.listen(currentLocationProvider, (prev, next) {
      if (next.lat != AppConstants.ouagaCenterLatitude ||
          next.lon != AppConstants.ouagaCenterLongitude) {
        _enableLocationComponent();
        flyTo(next.lat, next.lon, zoom: 16.0);
      }
    });

    final hasToken = EnvConfig.mapboxToken.isNotEmpty;

    return Stack(
      children: [
        if (hasToken)
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTapUp: (details) => _onMapTapped(details.localPosition),
            child: mb.MapWidget(
              key: const ValueKey('mapbox_main_map'),
              styleUri: _currentStyle.uri,
              onMapCreated: _onMapCreated,
              onMapIdleListener: (event) {
                _placesController?.onCameraIdle();
              },
            ),
          )
        else
          _buildMissingTokenBanner(context),

        // 1. BADGE FLOTTANT "✅ Hors-ligne prêt"
        Positioned(
          left: 20,
          bottom: 270,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(
                  Icons.check_circle_rounded,
                  color: Color(0xFF22C55E),
                  size: 16,
                ),
                SizedBox(width: 6),
                Text(
                  'Hors-ligne prêt',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF374151),
                  ),
                ),
              ],
            ),
          ),
        ),

        // 2. CONTRÔLES FLOTTANTS DE CARTE (Calques & Recentrage GPS)
        Positioned(
          right: 16,
          bottom: 270,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Bouton Signaler un incident routier
              if (widget.onReportTap != null) ...[
                GestureDetector(
                  onTap: widget.onReportTap,
                  child: Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: const Color(0xFFFEF2F2),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFFCA5A5),
                        width: 1.5,
                      ),
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
              ],

              // Bouton Calques & Styles Mapbox
              GestureDetector(
                onTap: () => _showMapStyleModal(context),
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppColors.primary,
                      width: 1.5,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.12),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Icon(
                    _currentStyle.icon,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // Bouton Recentrage GPS
              GestureDetector(
                onTap: _handleRecenter,
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
                  child: const Icon(
                    Icons.my_location_rounded,
                    color: AppColors.primary,
                    size: 24,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMissingTokenBanner(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(24),
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.amber.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.vpn_key_rounded,
              size: 48,
              color: Colors.amber,
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Configuration du Token Mapbox',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            'Le paquet mapbox_maps_flutter 3.0.0 est installé avec succès.\n'
            'Pour afficher la carte vectorielle, renseignez votre MAPBOX_TOKEN dans .env ou avec :\n\n'
            'flutter run --dart-define=MAPBOX_TOKEN=pk.xxxxxxxx',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white70,
              fontSize: 13,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
