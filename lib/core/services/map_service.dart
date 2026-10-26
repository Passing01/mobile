import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:qvgestion_mobile/core/theme/map_theme.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
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
  Future<void> moveCamera({required double lat, required double lng, double zoom = 14.0});
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
  Future<void> updateUserLocation(double lat, double lon);
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
  static const String placesPointsLayerId = 'places-points';
  static const String placesLabelsLayerId = 'places-labels';

  static const String routeSourceId = 'fasonav-route-source';
  static const String routeCasingLayerId = 'fasonav-route-casing';
  static const String routeLayerId = 'fasonav-route-layer';

  static const String userLocationSourceId = 'fasonav-user-location-source';
  static const String userLocationAuraLayerId = 'fasonav-user-location-aura';
  static const String userLocationRingLayerId = 'fasonav-user-location-ring';
  static const String userLocationCoreLayerId = 'fasonav-user-location-core';

  static const String selectedPlaceSourceId = 'fasonav-selected-place-source';
  static const String selectedPlaceAuraLayerId = 'fasonav-selected-place-aura';
  static const String selectedPlacePinLayerId = 'fasonav-selected-place-pin';
  static const String selectedPlaceLabelLayerId = 'fasonav-selected-place-label';

  double? _userLat;
  double? _userLon;
  PlaceModel? _selectedPlace;

  @override
  bool get isReady => _controller != null && _layersConfigured;

  @override
  void attach(MapLibreMapController controller) {
    _controller = controller;
    _layersConfigured = false;
  }

  @override
  Future<void> setupLayers({MapTheme theme = MapTheme.light}) async {
    final c = _controller;
    if (c == null) return;
    _currentTheme = theme;

    try {
      // 1. Initialisation de la source des lieux avec grappes (clustering conforme Étape 4)
      final placesData = _cachedPlacesGeoJson ?? _buildPlacesGeoJson(_cachedPlaces);
      await c.addSource(
        placesSourceId,
        GeojsonSourceProperties(
          data: placesData,
          cluster: true,
          clusterRadius: 48,
          clusterMaxZoom: 14,
        ),
      );

      // Couche des grappes (cercles bleu foncé avec contour blanc et rayon adaptatif)
      await c.addCircleLayer(
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
        enableInteraction: true,
      );

      // Couche du libellé chiffré au centre de la grappe
      await c.addSymbolLayer(
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

      // Couche des points individuels colorés selon leur catégorie (gros points avec contour blanc)
      await c.addCircleLayer(
        placesSourceId,
        placesPointsLayerId,
        MapTheme.placeCircleProperties,
        filter: ['!', [Expressions.has, 'point_count']],
        enableInteraction: true,
      );

      // Couche des étiquettes des lieux à partir du zoom 14
      await c.addSymbolLayer(
        placesSourceId,
        placesLabelsLayerId,
        const SymbolLayerProperties(
          textField: [Expressions.get, 'name'],
          textSize: 12.0,
          textOffset: [0, 1.6],
          textColor: '#2B2A27',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 1.5,
        ),
        filter: ['!', [Expressions.has, 'point_count']],
        minzoom: 14.0,
        enableInteraction: false,
      );

      // 2. Initialisation de la source et des couches de tracé d'itinéraire (liseré de contraste + intérieur)
      final routeGeoJson = _buildRouteGeoJson(_cachedRoute);
      await c.addGeoJsonSource(routeSourceId, routeGeoJson);

      // 2.1 Couche de liseré de contraste (blanc en clair, très sombre en nuit)
      await c.addLineLayer(
        routeSourceId,
        routeCasingLayerId,
        LineLayerProperties(
          lineColor: theme.routeCasing,
          lineWidth: 8.5,
          lineJoin: 'round',
          lineCap: 'round',
        ),
        enableInteraction: false,
      );

      // 2.2 Couche intérieure du tracé (bleu vif haute lisibilité)
      await c.addLineLayer(
        routeSourceId,
        routeLayerId,
        LineLayerProperties(
          lineColor: theme.route,
          lineWidth: 6.0,
          lineJoin: 'round',
          lineCap: 'round',
        ),
        enableInteraction: false,
      );

      // 3. Initialisation de la source et couches du lieu sélectionné (repère de destination / pin)
      final selectedGeoJson = _buildPointGeoJson(
        _selectedPlace?.latitude,
        _selectedPlace?.longitude,
        properties: {'title': _selectedPlace?.nom ?? ''},
      );
      await c.addGeoJsonSource(selectedPlaceSourceId, selectedGeoJson);

      await c.addCircleLayer(
        selectedPlaceSourceId,
        selectedPlaceAuraLayerId,
        const CircleLayerProperties(
          circleColor: '#E53935',
          circleOpacity: 0.25,
          circleRadius: 22.0,
        ),
        enableInteraction: false,
      );

      await c.addCircleLayer(
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

      await c.addSymbolLayer(
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

      // 4. Initialisation de la source et couches de la position de l'utilisateur (GPS Puck)
      final userGeoJson = _buildPointGeoJson(_userLat, _userLon, properties: {'title': 'Ma position'});
      await c.addGeoJsonSource(userLocationSourceId, userGeoJson);

      await c.addCircleLayer(
        userLocationSourceId,
        userLocationAuraLayerId,
        const CircleLayerProperties(
          circleColor: '#1A73E8',
          circleOpacity: 0.20,
          circleRadius: 18.0,
        ),
        enableInteraction: false,
      );

      await c.addCircleLayer(
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

      await c.addCircleLayer(
        userLocationSourceId,
        userLocationCoreLayerId,
        const CircleLayerProperties(
          circleColor: '#1A73E8',
          circleRadius: 5.5,
        ),
        enableInteraction: false,
      );

      _layersConfigured = true;
      AppLogger.i('Couches MapLibre configurées avec succès (Thème: ${theme.isDark ? "Dark" : "Light"})');
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
    _cachedPlacesGeoJson = featureCollection;
    final c = _controller;
    if (c == null || !_layersConfigured) return;

    try {
      await c.setGeoJsonSource(placesSourceId, featureCollection);
    } catch (e) {
      AppLogger.w('Mise à jour source places MapLibre: $e');
    }
  }

  @override
  Future<void> setRoute(RouteModel? route) async {
    _cachedRoute = route;
    final c = _controller;
    if (c == null || !_layersConfigured) return;

    try {
      final geojson = _buildRouteGeoJson(route);
      await c.setGeoJsonSource(routeSourceId, geojson);

      if (route != null && route.boundingBox.length >= 4) {
        final minLat = route.boundingBox[0];
        final minLon = route.boundingBox[1];
        final maxLat = route.boundingBox[2];
        final maxLon = route.boundingBox[3];
        if (minLat.isFinite && maxLat.isFinite && minLon.isFinite && maxLon.isFinite) {
          await fitBounds(
            minLat: minLat,
            minLon: minLon,
            maxLat: maxLat,
            maxLon: maxLon,
            padding: 80.0,
          );
        }
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
      await c.setGeoJsonSource(
        routeSourceId,
        const {'type': 'FeatureCollection', 'features': []},
      );
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
      final geojson = _buildPointGeoJson(lat, lon, properties: {'title': 'Ma position'});
      await c.setGeoJsonSource(userLocationSourceId, geojson);
    } catch (e) {
      AppLogger.d('Mise à jour position utilisateur: $e');
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
          CameraPosition(
            target: LatLng(lat, lng),
            zoom: zoom.clamp(3.0, 20.0),
          ),
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
      // Boîte tactile d'au moins 48px autour du doigt pour un confort optimal en extérieur
      final touchBox = Rect.fromCenter(
        center: Offset(point.x, point.y),
        width: 48.0,
        height: 48.0,
      );

      final features = await c.queryRenderedFeaturesInRect(
        touchBox,
        [placesPointsLayerId],
        null,
      );

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
  void dispose() {
    _controller = null;
    _layersConfigured = false;
  }

  Map<String, dynamic> _buildPlacesGeoJson(List<PlaceModel> places) {
    return {
      'type': 'FeatureCollection',
      'features': places.map((p) => p.toGeoJsonFeature()).toList(),
    };
  }

  Map<String, dynamic> _buildRouteGeoJson(RouteModel? route) {
    if (route == null || route.geometry.length < 2) {
      return const {
        'type': 'FeatureCollection',
        'features': [],
      };
    }

    final coords = <List<double>>[];
    for (final pt in route.geometry) {
      if (pt.length >= 2 && pt[0].isFinite && pt[1].isFinite) {
        coords.add([pt[1].toDouble(), pt[0].toDouble()]); // [lng, lat] GeoJSON standard
      }
    }

    return {
      'type': 'FeatureCollection',
      'features': [
        {
          'type': 'Feature',
          'geometry': {
            'type': 'LineString',
            'coordinates': coords,
          },
          'properties': {
            'mode': route.mode,
            'distance': route.distanceMeters,
          },
        },
      ],
    };
  }

  Map<String, dynamic> _buildPointGeoJson(double? lat, double? lon, {Map<String, dynamic>? properties}) {
    if (lat == null || lon == null || !lat.isFinite || !lon.isFinite) {
      return const {
        'type': 'FeatureCollection',
        'features': [],
      };
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
        }
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
