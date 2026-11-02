import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:qvgestion_mobile/core/theme/map_theme.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/core/utils/map_pin_generator.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

/// Interface unifiée cachant le moteur cartographique au reste de l'application
/// Permet l'interchangeabilité complète du moteur sans impacter les écrans.
abstract class MapService {
  void attach(MapLibreMapController controller);
  bool get isReady;
  Future<void> setupLayers({MapTheme theme = MapTheme.light});
  Future<void> setPlaces(List<PlaceModel> places);
  Future<void> showPlaces(Map<String, dynamic> featureCollection);
  Map<String, dynamic>? get cachedPlacesGeoJson;
  MapLibreMapController? get controller;
  Future<void> setRoute(RouteModel? route);
  Future<void> clearRoute();
  Future<void> moveCamera({
    required double lat,
    required double lng,
    double zoom = 14.0,
  });
  Future<void> animateCamera({
    required double lat,
    required double lng,
    double zoom = 15.0,
    double? bearing,
    double? tilt,
  });
  Future<void> fitBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    double padding = 50.0,
  });
  Future<PlaceModel?> queryPlaceAt(Point<double> point);
  Future<List<Map<String, dynamic>>> queryTapFeatures(Point<double> point);
  Future<void> highlightFeature(Map<String, dynamic> feature);
  Future<void> clearHighlight();
  Future<void> dropDestinationPin(LatLng geo);
  Future<void> clearDestinationPin();
  Future<void> zoomIn(LatLng geo, {double delta = 2.0});
  Future<void> updateUserLocation(double lat, double lon);
  Future<void> setTransportMode(String? mode);
  Future<void> setSelectedPlace(PlaceModel? place);
  MapTheme get currentTheme;
  void dispose();
}

/// Implémentation officielle basée sur MapLibre Native et OpenStreetMap
class MapLibreMapService implements MapService {
  MapLibreMapController? _controller;
  bool _layersConfigured = false;
  List<PlaceModel> _cachedPlaces = [];
  Map<String, dynamic>? _cachedPlacesGeoJson;
  RouteModel? _cachedRoute;
  MapTheme _currentTheme = MapTheme.light;

  @override
  MapTheme get currentTheme => _currentTheme;

  @override
  MapLibreMapController? get controller => _controller;

  @override
  Map<String, dynamic>? get cachedPlacesGeoJson => _cachedPlacesGeoJson;

  static const String placesSourceId = 'places';
  static const String placesClusterLayerId = 'places-clusters';
  static const String placesClusterCountLayerId = 'places-cluster-count';
  static const String placesCirclesLayerId = 'places-pin-circles';
  static const String placesPointsLayerId = 'places-points';
  static const String placesLabelsLayerId = 'places-labels';

  static const String routeSourceId = 'route';
  static const String routeCasingLayerId = 'route-casing';
  static const String routeLayerId = 'route-line';

  static const String userLocationSourceId = 'fasonav-user-location-source';
  static const String userLocationAuraLayerId = 'fasonav-user-location-aura';
  static const String userLocationRingLayerId = 'fasonav-user-location-ring';
  static const String userLocationCoreLayerId = 'fasonav-user-location-core';
  static const String userLocationModeLayerId = 'fasonav-user-location-mode';

  static const String selectedPlaceSourceId = 'fasonav-selected-place-source';
  static const String selectedPlaceAuraLayerId = 'fasonav-selected-place-aura';
  static const String selectedPlacePinLayerId = 'fasonav-selected-place-pin';
  static const String selectedPlaceLabelLayerId =
      'fasonav-selected-place-label';

  // Couches officielles Étape 5 (Halo et Destination libre)
  static const String selectedSourceId = 'selected';
  static const String selectedRingLayerId = 'selected-ring';
  static const String destinationPinSourceId = 'destination-pin';
  static const String destinationPinAuraLayerId = 'destination-pin-aura';
  static const String destinationPinLayerId = 'destination-pin-layer';
  static const String destinationPinLabelLayerId = 'destination-pin-label';

  double? _userLat;
  double? _userLon;
  String? _transportMode = 'moto';
  PlaceModel? _selectedPlace;

  String _modeIconFor(String? mode) {
    if (mode == null || mode.isEmpty || mode == 'default' || mode == 'none') {
      return 'user-location-pin';
    }
    final m = mode.toLowerCase().trim();
    if (m == 'pied' || m == 'pedestrian' || m == 'walk') return 'mode-pied';
    if (m == 'voiture' || m == 'auto' || m == 'car') return 'mode-voiture';
    if (m == 'velo' || m == 'bicycle' || m == 'bike') return 'mode-velo';
    if (m == 'moto' || m == 'motorcycle') return 'mode-moto';
    return 'user-location-pin';
  }

  String _modeLabelFor(String? mode) {
    if (mode == null || mode.isEmpty || mode == 'default' || mode == 'none') {
      return 'Ma position';
    }
    final m = mode.toLowerCase().trim();
    if (m == 'pied' || m == 'pedestrian' || m == 'walk') return 'Ma position • À pied';
    if (m == 'voiture' || m == 'auto' || m == 'car') return 'Ma position • Voiture';
    if (m == 'velo' || m == 'bicycle' || m == 'bike') return 'Ma position • Vélo';
    if (m == 'moto' || m == 'motorcycle') return 'Ma position • Moto';
    return 'Ma position';
  }

  @override
  bool get isReady => _controller != null && _layersConfigured;

  @override
  void attach(MapLibreMapController controller) {
    _controller = controller;
    _layersConfigured = false;
  }

  Future<void> _safeAddGeoJsonSource(
    MapLibreMapController c,
    Set<String> existingSources,
    String id,
    Map<String, dynamic> geojson, {
    bool cluster = false,
    double? clusterRadius,
    double? clusterMaxZoom,
  }) async {
    if (!existingSources.contains(id)) {
      try {
        if (cluster) {
          await c.addSource(
            id,
            GeojsonSourceProperties(
              data: geojson,
              cluster: true,
              clusterRadius: clusterRadius,
              clusterMaxZoom: clusterMaxZoom,
            ),
          );
        } else {
          await c.addGeoJsonSource(id, geojson);
        }
        existingSources.add(id);
      } catch (e) {
        if (!e.toString().contains('already exists')) {
          AppLogger.w('Erreur addGeoJsonSource $id: $e');
        }
      }
    } else {
      try {
        await c.setGeoJsonSource(id, geojson);
      } catch (e) {
        AppLogger.w('Erreur setGeoJsonSource $id: $e');
      }
    }
  }

  Future<void> _safeAddCircleLayer(
    MapLibreMapController c,
    Set<String> existingLayers,
    String sourceId,
    String layerId,
    CircleLayerProperties properties, {
    String? belowLayerId,
    bool enableInteraction = false,
    dynamic filter,
  }) async {
    if (!existingLayers.contains(layerId)) {
      try {
        await c.addCircleLayer(
          sourceId,
          layerId,
          properties,
          belowLayerId: belowLayerId,
          enableInteraction: enableInteraction,
          filter: filter,
        );
        existingLayers.add(layerId);
      } catch (e) {
        if (!e.toString().contains('already exists')) {
          AppLogger.w('Erreur addCircleLayer $layerId: $e');
        }
      }
    }
  }

  Future<void> _safeAddSymbolLayer(
    MapLibreMapController c,
    Set<String> existingLayers,
    String sourceId,
    String layerId,
    SymbolLayerProperties properties, {
    String? belowLayerId,
    bool enableInteraction = false,
    dynamic filter,
  }) async {
    if (!existingLayers.contains(layerId)) {
      try {
        await c.addSymbolLayer(
          sourceId,
          layerId,
          properties,
          belowLayerId: belowLayerId,
          enableInteraction: enableInteraction,
          filter: filter,
        );
        existingLayers.add(layerId);
      } catch (e) {
        if (!e.toString().contains('already exists')) {
          AppLogger.w('Erreur addSymbolLayer $layerId: $e');
        }
      }
    }
  }

  Future<void> _safeAddLineLayer(
    MapLibreMapController c,
    Set<String> existingLayers,
    String sourceId,
    String layerId,
    LineLayerProperties properties, {
    String? belowLayerId,
    bool enableInteraction = false,
  }) async {
    if (!existingLayers.contains(layerId)) {
      try {
        await c.addLineLayer(
          sourceId,
          layerId,
          properties,
          belowLayerId: belowLayerId,
          enableInteraction: enableInteraction,
        );
        existingLayers.add(layerId);
      } catch (e) {
        if (!e.toString().contains('already exists')) {
          AppLogger.w('Erreur addLineLayer $layerId: $e');
        }
      }
    }
  }

  @override
  Future<void> setupLayers({MapTheme theme = MapTheme.light}) async {
    final c = _controller;
    if (c == null) return;
    _currentTheme = theme;

    try {
      Set<String> existingSources = {};
      Set<String> existingLayers = {};
      try {
        existingSources = (await c.getSourceIds()).cast<String>().toSet();
        existingLayers = (await c.getLayerIds()).cast<String>().toSet();
      } catch (_) {}

      // 1. Initialisation de la source des lieux avec grappes (clustering conforme Étape 4)
      final rawPlacesData =
          _cachedPlacesGeoJson ?? _buildPlacesGeoJson(_cachedPlaces);
      final placesData = _cleanPlacesGeoJson(rawPlacesData);
      await _safeAddGeoJsonSource(
        c,
        existingSources,
        placesSourceId,
        placesData,
        cluster: true,
        clusterRadius: 36.0,
        clusterMaxZoom: 12.0,
      );

      // Couche des grappes (cercles bleu foncé avec contour blanc et rayon adaptatif)
      await _safeAddCircleLayer(
        c,
        existingLayers,
        placesSourceId,
        placesClusterLayerId,
        const CircleLayerProperties(
          circleColor: '#1E3A5F',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3.0,
          circleRadius: [
            Expressions.step,
            [Expressions.get, 'point_count'],
            18.0,
            10,
            24.0,
            50,
            32.0,
          ],
        ),
        filter: [Expressions.has, 'point_count'],
        enableInteraction: false,
      );

      // Couche du libellé chiffré au centre de la grappe
      await _safeAddSymbolLayer(
        c,
        existingLayers,
        placesSourceId,
        placesClusterCountLayerId,
        const SymbolLayerProperties(
          textField: [Expressions.get, 'point_count_abbreviated'],
          textColor: '#FFFFFF',
          textSize: 14.0,
          textAllowOverlap: true,
        ),
        filter: [Expressions.has, 'point_count'],
        enableInteraction: false,
      );

      // Enregistrement des icônes pins officielles de FASO NAV
      try {
        final allPins = await MapPinGenerator.generateAllPins();
        for (final entry in allPins.entries) {
          await c.addImage(entry.key, entry.value);
        }
      } catch (e) {
        AppLogger.w('Enregistrement des icônes pins: $e');
      }

      // Couche des repères circulaires (point coloré haute fiabilité)
      await _safeAddCircleLayer(
        c,
        existingLayers,
        placesSourceId,
        placesCirclesLayerId,
        const CircleLayerProperties(
          circleColor: [
            Expressions.coalesce,
            [Expressions.get, 'color'],
            '#2563EB',
          ],
          circleRadius: 6.5,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 2.0,
        ),
        filter: [
          '!',
          [Expressions.has, 'point_count'],
        ],
        enableInteraction: false,
      );

      // Couche des lieux : icône Maps de catégorie avec push/badge en haut affichant le nom
      await _safeAddSymbolLayer(
        c,
        existingLayers,
        placesSourceId,
        placesPointsLayerId,
        const SymbolLayerProperties(
          iconImage: [
            Expressions.coalesce,
            [Expressions.get, 'icon'],
            'pin-default',
          ],
          iconSize: 0.65,
          iconAnchor: 'bottom',
          iconAllowOverlap: true,
          iconOptional: true,
          textField: [Expressions.get, 'name'],
          textSize: 11.0,
          textColor: '#0F172A',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2.2,
          textAnchor: 'top',
          textOffset: [0, 0.4],
          textAllowOverlap: false,
          textOptional: true,
        ),
        filter: [
          '!',
          [Expressions.has, 'point_count'],
        ],
        enableInteraction: false,
      );

      // Couche du halo de sélection (conforme Étape 5 : rayon 22, transparent centre, blanc 4px sous places-points)
      await _safeAddGeoJsonSource(c, existingSources, selectedSourceId, const {
        'type': 'FeatureCollection',
        'features': [],
      });
      await _safeAddCircleLayer(
        c,
        existingLayers,
        selectedSourceId,
        selectedRingLayerId,
        const CircleLayerProperties(
          circleRadius: 22.0,
          circleColor: '#00000000',
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 4.0,
        ),
        belowLayerId: placesPointsLayerId,
        enableInteraction: false,
      );

      // Source et couches de l'épingle « Destination » (appui long libre avec confirmation)
      await _safeAddGeoJsonSource(
        c,
        existingSources,
        destinationPinSourceId,
        const {'type': 'FeatureCollection', 'features': []},
      );
      await _safeAddCircleLayer(
        c,
        existingLayers,
        destinationPinSourceId,
        destinationPinAuraLayerId,
        const CircleLayerProperties(
          circleColor: '#E53935',
          circleOpacity: 0.25,
          circleRadius: 22.0,
        ),
        enableInteraction: false,
      );
      await _safeAddCircleLayer(
        c,
        existingLayers,
        destinationPinSourceId,
        destinationPinLayerId,
        const CircleLayerProperties(
          circleColor: '#E53935',
          circleRadius: 10.0,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3.0,
        ),
        enableInteraction: false,
      );
      await _safeAddSymbolLayer(
        c,
        existingLayers,
        destinationPinSourceId,
        destinationPinLabelLayerId,
        const SymbolLayerProperties(
          textField: 'Destination',
          textFont: ['Noto Sans Bold'],
          textSize: 12.0,
          textColor: '#FFFFFF',
          textHaloColor: '#E53935',
          textHaloWidth: 2.0,
          textOffset: [0, -2.4],
          textAnchor: 'bottom',
        ),
        enableInteraction: false,
      );

      // 2. Initialisation de la source et des couches de tracé d'itinéraire (liseré de contraste + intérieur)
      final routeGeoJson = _buildRouteGeoJson(_cachedRoute);
      await _safeAddGeoJsonSource(
        c,
        existingSources,
        routeSourceId,
        routeGeoJson,
      );

      // 2.1 Couche de liseré de contraste (blanc en clair, très sombre en nuit)
      await _safeAddLineLayer(
        c,
        existingLayers,
        routeSourceId,
        routeCasingLayerId,
        LineLayerProperties(
          lineColor: theme.routeCasing,
          lineWidth: 10.0,
          lineJoin: 'round',
          lineCap: 'round',
        ),
        belowLayerId: placesPointsLayerId,
        enableInteraction: false,
      );

      // 2.2 Couche intérieure du tracé (bleu vif haute lisibilité)
      await _safeAddLineLayer(
        c,
        existingLayers,
        routeSourceId,
        routeLayerId,
        LineLayerProperties(
          lineColor: theme.route,
          lineWidth: 6.0,
          lineJoin: 'round',
          lineCap: 'round',
        ),
        belowLayerId: placesPointsLayerId,
        enableInteraction: false,
      );

      // 3. Initialisation de la source et couches du lieu sélectionné (repère de destination / pin)
      final selectedGeoJson = _buildPointGeoJson(
        _selectedPlace?.latitude,
        _selectedPlace?.longitude,
        properties: {'title': _selectedPlace?.nom ?? ''},
      );
      await _safeAddGeoJsonSource(
        c,
        existingSources,
        selectedPlaceSourceId,
        selectedGeoJson,
      );

      await _safeAddCircleLayer(
        c,
        existingLayers,
        selectedPlaceSourceId,
        selectedPlaceAuraLayerId,
        const CircleLayerProperties(
          circleColor: '#E53935',
          circleOpacity: 0.25,
          circleRadius: 22.0,
        ),
        enableInteraction: false,
      );

      await _safeAddCircleLayer(
        c,
        existingLayers,
        selectedPlaceSourceId,
        selectedPlacePinLayerId,
        const CircleLayerProperties(
          circleColor: '#E53935',
          circleRadius: 10.0,
          circleStrokeColor: '#FFFFFF',
          circleStrokeWidth: 3.0,
        ),
        enableInteraction: false,
      );

      await _safeAddSymbolLayer(
        c,
        existingLayers,
        selectedPlaceSourceId,
        selectedPlaceLabelLayerId,
        SymbolLayerProperties(
          textField: [Expressions.get, 'title'],
          textFont: const ['Noto Sans Bold'],
          textSize: 12.0,
          textColor: theme.label,
          textHaloColor: theme.halo,
          textHaloWidth: 2.0,
          textOffset: const [0, -2.0],
        ),
        enableInteraction: false,
      );

      // 4. Initialisation de la source et couches de la position de l'utilisateur (GPS Puck + Avatar Mode)
      final userGeoJson = _buildPointGeoJson(
        _userLat,
        _userLon,
        properties: {
          'title': 'Ma position',
          'mode_icon': _modeIconFor(_transportMode),
          'mode_label': _modeLabelFor(_transportMode),
        },
      );
      await _safeAddGeoJsonSource(c, existingSources, userLocationSourceId, userGeoJson);

      await _safeAddCircleLayer(
        c,
        existingLayers,
        userLocationSourceId,
        userLocationAuraLayerId,
        const CircleLayerProperties(
          circleColor: '#1A73E8',
          circleOpacity: 0.20,
          circleRadius: 18.0,
        ),
        enableInteraction: false,
      );

      await _safeAddCircleLayer(
        c,
        existingLayers,
        userLocationSourceId,
        userLocationRingLayerId,
        const CircleLayerProperties(
          circleColor: '#FFFFFF',
          circleRadius: 8.5,
          circleStrokeColor: '#1A73E8',
          circleStrokeWidth: 1.5,
        ),
        enableInteraction: false,
      );

      await _safeAddCircleLayer(
        c,
        existingLayers,
        userLocationSourceId,
        userLocationCoreLayerId,
        const CircleLayerProperties(circleColor: '#1A73E8', circleRadius: 5.5),
        enableInteraction: false,
      );

      await _safeAddSymbolLayer(
        c,
        existingLayers,
        userLocationSourceId,
        userLocationModeLayerId,
        const SymbolLayerProperties(
          iconImage: [
            Expressions.match,
            [
              Expressions.coalesce,
              [Expressions.get, 'mode_icon'],
              'mode-moto',
            ],
            'mode-moto',
            'mode-moto',
            'mode-voiture',
            'mode-voiture',
            'mode-pied',
            'mode-pied',
            'mode-velo',
            'mode-velo',
            'mode-moto',
          ],
          iconSize: 0.90,
          iconAnchor: 'bottom',
          iconAllowOverlap: true,
          iconIgnorePlacement: true,
          textField: [Expressions.get, 'mode_label'],
          textSize: 11.5,
          textColor: '#0F172A',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2.2,
          textAnchor: 'top',
          textOffset: [0, 0.7],
          textFont: ['Noto Sans Bold'],
          textAllowOverlap: true,
          textIgnorePlacement: true,
        ),
        enableInteraction: false,
      );

      _layersConfigured = true;
      AppLogger.i(
        'Couches MapLibre configurées avec succès (Thème: ${theme.isDark ? "Dark" : "Light"})',
      );
    } catch (e) {
      AppLogger.w('Initialisation couches MapLibre: $e');
    }
  }

  @override
  Future<void> setPlaces(List<PlaceModel> places) async {
    _cachedPlaces = List.unmodifiable(places);
    final geojson = _buildPlacesGeoJson(places);
    await showPlaces(geojson);
  }

  @override
  Future<void> showPlaces(Map<String, dynamic> featureCollection) async {
    final clean = _cleanPlacesGeoJson(featureCollection);
    _cachedPlacesGeoJson = clean;
    final c = _controller;
    if (c == null || !_layersConfigured) return;

    try {
      await c.setGeoJsonSource(placesSourceId, clean);
    } catch (e) {
      AppLogger.w('Mise à jour source places MapLibre: $e');
    }
  }

  @override
  Future<void> setRoute(RouteModel? route) async {
    _cachedRoute = route;
    final c = _controller;
    if (c == null || !_layersConfigured) return;

    if (route == null || route.geometry.length < 2) {
      await clearRoute();
      return;
    }

    try {
      final geojson = _buildRouteGeoJson(route);
      final features = geojson['features'] as List;
      if (features.isNotEmpty) {
        final geom = features.first['geometry'] as Map<String, dynamic>;
        final coords = geom['coordinates'] as List;
        await c.setGeoJsonSource(routeSourceId, geojson);
        await _fitToRoute(coords);
      }
    } catch (e) {
      AppLogger.w('Mise à jour tracé itinéraire MapLibre: $e');
    }
  }

  @override
  Future<void> clearRoute() async {
    _cachedRoute = null;
    final c = _controller;
    if (c == null || !_layersConfigured) return;

    try {
      await c.setGeoJsonSource(routeSourceId, const {
        'type': 'FeatureCollection',
        'features': [],
      });
    } catch (e) {
      AppLogger.d('Effacement tracé itinéraire: $e');
    }
  }

  @override
  Future<void> updateUserLocation(double lat, double lon) async {
    _userLat = lat;
    _userLon = lon;
    final c = _controller;
    if (c == null || !_layersConfigured) return;

    try {
      final geojson = _buildPointGeoJson(
        lat,
        lon,
        properties: {
          'title': 'Ma position',
          'mode_icon': _modeIconFor(_transportMode),
          'mode_label': _modeLabelFor(_transportMode),
        },
      );
      await c.setGeoJsonSource(userLocationSourceId, geojson);
    } catch (e) {
      AppLogger.d('Mise à jour position utilisateur: $e');
    }
  }

  @override
  Future<void> setTransportMode(String? mode) async {
    _transportMode = (mode == null || mode.isEmpty || mode == 'none' || mode == 'default') ? null : mode;
    final lat = _userLat;
    final lon = _userLon;
    if (lat != null && lon != null) {
      await updateUserLocation(lat, lon);
    }
  }

  @override
  Future<void> setSelectedPlace(PlaceModel? place) async {
    _selectedPlace = place;
    final c = _controller;
    if (c == null || !_layersConfigured) return;

    try {
      final geojson = _buildPointGeoJson(
        place?.latitude,
        place?.longitude,
        properties: {'title': place?.nom ?? ''},
      );
      await c.setGeoJsonSource(selectedPlaceSourceId, geojson);
    } catch (e) {
      AppLogger.d('Mise à jour lieu sélectionné: $e');
    }
  }

  @override
  Future<void> moveCamera({
    required double lat,
    required double lng,
    double zoom = 14.0,
  }) async {
    final c = _controller;
    if (c == null || !lat.isFinite || !lng.isFinite) return;

    try {
      await c.moveCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: zoom.clamp(3.0, 20.0)),
        ),
      );
    } catch (e) {
      AppLogger.d('Déplacement caméra MapLibre: $e');
    }
  }

  @override
  Future<void> animateCamera({
    required double lat,
    required double lng,
    double zoom = 15.0,
    double? bearing,
    double? tilt,
  }) async {
    final c = _controller;
    if (c == null || !lat.isFinite || !lng.isFinite) return;

    try {
      await c.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(
            target: LatLng(lat, lng),
            zoom: zoom.clamp(3.0, 20.0),
            bearing: bearing ?? 0.0,
            tilt: tilt ?? 0.0,
          ),
        ),
      );
    } catch (e) {
      AppLogger.d('Animation caméra MapLibre: $e');
    }
  }

  @override
  Future<void> fitBounds({
    required double minLat,
    required double minLon,
    required double maxLat,
    required double maxLon,
    double padding = 50.0,
  }) async {
    final c = _controller;
    if (c == null) return;

    try {
      await c.animateCamera(
        CameraUpdate.newLatLngBounds(
          LatLngBounds(
            southwest: LatLng(minLat, minLon),
            northeast: LatLng(maxLat, maxLon),
          ),
          left: padding,
          top: padding,
          right: padding,
          bottom: padding,
        ),
      );
    } catch (e) {
      AppLogger.d('Ajustement vue boîte englobante MapLibre: $e');
    }
  }

  @override
  Future<PlaceModel?> queryPlaceAt(Point<double> point) async {
    final c = _controller;
    if (c == null || !_layersConfigured) return null;

    try {
      // Boîte tactile confortable autour du doigt pour attraper le pin ou son badge
      final touchBox = Rect.fromCenter(
        center: Offset(point.x, point.y),
        width: 60.0,
        height: 72.0,
      );

      final features = await c.queryRenderedFeaturesInRect(touchBox, [
        placesPointsLayerId,
        placesCirclesLayerId,
      ], null);

      if (features.isNotEmpty) {
        final feature = features.first;
        if (feature is Map) {
          final props = feature['properties'] as Map?;
          final geom = feature['geometry'] as Map?;
          if (props != null && geom != null) {
            final coords = geom['coordinates'] as List?;
            final lon = (coords?[0] as num?)?.toDouble() ?? 0.0;
            final lat = (coords?[1] as num?)?.toDouble() ?? 0.0;
            final name = props['name']?.toString() ?? 'Lieu sélectionné';
            final idStr = props['id']?.toString();
            final parsedId = int.tryParse(idStr ?? '') ?? 999;

            return PlaceModel(
              id: parsedId,
              uuid: idStr,
              nom: name,
              categorieId: 1,
              latitude: lat,
              longitude: lon,
            );
          }
        }
      }
    } catch (e) {
      AppLogger.d('Interrogation entités sous le doigt: $e');
    }
    return null;
  }

  @override
  Future<List<Map<String, dynamic>>> queryTapFeatures(
    Point<double> point,
  ) async {
    final c = _controller;
    if (c == null || !_layersConfigured) return [];

    try {
      final rect = Rect.fromCenter(
        center: Offset(point.x, point.y - 8.0),
        width: 56.0,
        height: 64.0,
      );

      final raw = await c.queryRenderedFeaturesInRect(rect, [
        placesPointsLayerId,
        placesCirclesLayerId,
        placesClusterLayerId,
      ], null);

      final feats = <Map<String, dynamic>>[];
      for (final e in raw) {
        if (e is String) {
          try {
            feats.add(Map<String, dynamic>.from(jsonDecode(e) as Map));
          } catch (_) {}
        } else if (e is Map) {
          feats.add(Map<String, dynamic>.from(e));
        }
      }
      return feats;
    } catch (e) {
      AppLogger.d('Erreur queryTapFeatures: $e');
      return [];
    }
  }

  @override
  Future<void> highlightFeature(Map<String, dynamic> feature) async {
    final c = _controller;
    if (c == null || !_layersConfigured) return;
    try {
      await c.setGeoJsonSource(selectedSourceId, {
        'type': 'FeatureCollection',
        'features': [feature],
      });
    } catch (e) {
      AppLogger.w('Erreur highlightFeature: $e');
    }
  }

  @override
  Future<void> clearHighlight() async {
    final c = _controller;
    if (c == null || !_layersConfigured) return;
    try {
      await c.setGeoJsonSource(selectedSourceId, const {
        'type': 'FeatureCollection',
        'features': [],
      });
    } catch (e) {
      AppLogger.d('Erreur clearHighlight: $e');
    }
  }

  @override
  Future<void> dropDestinationPin(LatLng geo) async {
    final c = _controller;
    if (c == null || !_layersConfigured) return;
    try {
      await c.setGeoJsonSource(destinationPinSourceId, {
        'type': 'FeatureCollection',
        'features': [
          {
            'type': 'Feature',
            'geometry': {
              'type': 'Point',
              'coordinates': [geo.longitude, geo.latitude],
            },
            'properties': {'title': 'Destination'},
          },
        ],
      });
    } catch (e) {
      AppLogger.w('Erreur dropDestinationPin: $e');
    }
  }

  @override
  Future<void> clearDestinationPin() async {
    final c = _controller;
    if (c == null || !_layersConfigured) return;
    try {
      await c.setGeoJsonSource(destinationPinSourceId, const {
        'type': 'FeatureCollection',
        'features': [],
      });
    } catch (e) {
      AppLogger.d('Erreur clearDestinationPin: $e');
    }
  }

  @override
  Future<void> zoomIn(LatLng geo, {double delta = 2.0}) async {
    final c = _controller;
    if (c == null) return;
    try {
      final z = c.cameraPosition?.zoom ?? 12.5;
      final targetZoom = (z + delta).clamp(3.0, 20.0);
      await c.animateCamera(CameraUpdate.newLatLngZoom(geo, targetZoom));
    } catch (e) {
      AppLogger.w('Erreur zoomIn: $e');
    }
  }

  @override
  void dispose() {
    _controller = null;
    _layersConfigured = false;
  }

  Map<String, dynamic> _cleanPlacesGeoJson(dynamic raw) {
    if (raw is! Map) {
      return const {'type': 'FeatureCollection', 'features': []};
    }
    final rawFeatures = raw['features'];
    if (rawFeatures is! List) {
      return const {'type': 'FeatureCollection', 'features': []};
    }

    final cleanFeatures = <Map<String, dynamic>>[];
    for (final f in rawFeatures) {
      if (f is! Map) continue;
      final geom = f['geometry'];
      if (geom is! Map) continue;
      final coords = geom['coordinates'];
      if (coords is! List || coords.length < 2) continue;
      final lon = (coords[0] as num?)?.toDouble();
      final lat = (coords[1] as num?)?.toDouble();
      if (lon == null || lat == null || !lon.isFinite || !lat.isFinite) continue;

      final props = f['properties'] is Map
          ? Map<String, dynamic>.from(f['properties'] as Map)
          : <String, dynamic>{};
      final cat = (props['category_slug'] ??
              props['category'] ??
              props['categorie_slug'] ??
              'divers')
          .toString();
      final name = (props['name'] ?? props['nom'] ?? 'Lieu').toString();
      final id = (props['id'] ?? f['id'] ?? name).toString();
      final color = props['color']?.toString() ?? MapTheme.colorForCategory(cat);
      final iconName = _pinIconForCategory(cat);

      cleanFeatures.add({
        'type': 'Feature',
        'id': id,
        'geometry': {
          'type': 'Point',
          'coordinates': [lon, lat],
        },
        'properties': {
          'id': id,
          'name': name,
          'nom': name,
          'category': cat,
          'category_slug': cat,
          'color': color,
          'strokeColor': '#FFFFFF',
          'icon': iconName,
        },
      });
    }

    return {
      'type': 'FeatureCollection',
      'features': cleanFeatures,
    };
  }

  String _pinIconForCategory(String? slug) {
    final s = (slug ?? '').toLowerCase().trim();
    if (s.contains('pharmacie')) return 'pin-pharmacie';
    if (s.contains('station')) return 'pin-station-service';
    if (s.contains('maquis') || s.contains('resto') || s.contains('restaurant')) {
      return 'pin-maquis-restaurant';
    }
    if (s.contains('hopital') || s.contains('sante') || s.contains('clinique') || s.contains('csps')) {
      return 'pin-hopital-sante';
    }
    if (s.contains('banque') || s.contains('distributeur') || s.contains('atm')) {
      return 'pin-banque-distributeur';
    }
    if (s.contains('administration') || s.contains('mairie') || s.contains('police')) {
      return 'pin-administration';
    }
    if (s.contains('ecole') || s.contains('universite') || s.contains('lycee') || s.contains('college')) {
      return 'pin-ecole-universite';
    }
    if (s.contains('marche') || s.contains('commerce') || s.contains('boutique') || s.contains('alimentation')) {
      return 'pin-marche-commerce';
    }
    return 'pin-default';
  }

  Map<String, dynamic> _buildPlacesGeoJson(List<PlaceModel> places) {
    return {
      'type': 'FeatureCollection',
      'features': places.map((p) => p.toGeoJsonFeature()).toList(),
    };
  }

  Future<void> _fitToRoute(List<dynamic> coords) async {
    final c = _controller;
    if (c == null || coords.length < 2) return;

    double minLat = 90.0;
    double maxLat = -90.0;
    double minLon = 180.0;
    double maxLon = -180.0;

    for (final pt in coords) {
      if (pt is List && pt.length >= 2) {
        final lon = (pt[0] as num).toDouble();
        final lat = (pt[1] as num).toDouble();
        if (lat < minLat) minLat = lat;
        if (lat > maxLat) maxLat = lat;
        if (lon < minLon) minLon = lon;
        if (lon > maxLon) maxLon = lon;
      }
    }

    if (minLat <= maxLat && minLon <= maxLon) {
      await fitBounds(
        minLat: minLat,
        minLon: minLon,
        maxLat: maxLat,
        maxLon: maxLon,
        padding: 80.0,
      );
    }
  }

  Map<String, dynamic> _buildRouteGeoJson(RouteModel? route) {
    if (route == null || route.geometry.length < 2) {
      return const {'type': 'FeatureCollection', 'features': []};
    }

    final coords = <List<double>>[];
    for (final pt in route.geometry) {
      if (pt.length >= 2 && pt[0].isFinite && pt[1].isFinite) {
        // En GeoJSON standard : [longitude, latitude]
        final lon = pt[0] < 5.0 ? pt[0].toDouble() : pt[1].toDouble();
        final lat = pt[1] > 8.0 ? pt[1].toDouble() : pt[0].toDouble();
        coords.add([lon, lat]);
      }
    }

    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {'type': 'LineString', 'coordinates': coords},
          'properties': {'mode': route.mode, 'distance': route.distanceMeters},
        },
      ],
    };
  }

  Map<String, dynamic> _buildPointGeoJson(
    double? lat,
    double? lon, {
    Map<String, dynamic>? properties,
  }) {
    if (lat == null || lon == null || !lat.isFinite || !lon.isFinite) {
      return const {'type': 'FeatureCollection', 'features': []};
    }
    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'Point',
            'coordinates': [lon, lat],
          },
          'properties': properties ?? {},
        },
      ],
    };
  }
}

/// Provider pour injecter l'instance du MapService
final mapServiceProvider = Provider<MapService>((ref) {
  final service = MapLibreMapService();
  ref.onDispose(() => service.dispose());
  return service;
});
