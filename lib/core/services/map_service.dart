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
  Future<List<Map<String, dynamic>>> queryTapFeatures(Point<double> point);
  Future<void> highlightFeature(Map<String, dynamic> feature);
  Future<void> clearHighlight();
  Future<void> dropDestinationPin(LatLng geo);
  Future<void> clearDestinationPin();
  Future<void> zoomIn(LatLng geo, {double delta = 2.0});
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

  static const String routeSourceId = 'route';
  static const String routeCasingLayerId = 'route-casing';
  static const String routeLayerId = 'route-line';

  static const String userLocationSourceId = 'fasonav-user-location-source';
  static const String userLocationAuraLayerId = 'fasonav-user-location-aura';
  static const String userLocationRingLayerId = 'fasonav-user-location-ring';
  static const String userLocationCoreLayerId = 'fasonav-user-location-core';

  static const String selectedPlaceSourceId = 'fasonav-selected-place-source';
  static const String selectedPlaceAuraLayerId = 'fasonav-selected-place-aura';
  static const String selectedPlacePinLayerId = 'fasonav-selected-place-pin';
  static const String selectedPlaceLabelLayerId = 'fasonav-selected-place-label';

  // Couches officielles Étape 5 (Halo et Destination libre)
  static const String selectedSourceId = 'selected';
  static const String selectedRingLayerId = 'selected-ring';
  static const String destinationPinSourceId = 'destination-pin';
  static const String destinationPinAuraLayerId = 'destination-pin-aura';
  static const String destinationPinLayerId = 'destination-pin-layer';
  static const String destinationPinLabelLayerId = 'destination-pin-label';

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

      // Enregistrement des icônes pins officielles de FASO NAV
      try {
        final allPins = await MapPinGenerator.generateAllPins();
        for (final entry in allPins.entries) {
          await c.addImage(entry.key, entry.value);
        }
      } catch (e) {
        AppLogger.w('Enregistrement des icônes pins: $e');
      }

      // Couche des lieux : icône Maps de catégorie avec push/badge en haut affichant le nom
      await c.addSymbolLayer(
        placesSourceId,
        placesPointsLayerId,
        const SymbolLayerProperties(
          iconImage: [
            Expressions.match,
            [Expressions.coalesce, [Expressions.get, 'category_slug'], [Expressions.get, 'category'], ''],
            'pharmacie', 'pin-pharmacie',
            'station-service', 'pin-station-service',
            'maquis-restaurant', 'pin-maquis-restaurant',
            'hopital-sante', 'pin-hopital-sante',
            'banque-distributeur', 'pin-banque-distributeur',
            'administration', 'pin-administration',
            'ecole-universite', 'pin-ecole-universite',
            'marche-commerce', 'pin-marche-commerce',
            'pin-default',
          ],
          iconSize: 0.70,
          iconAnchor: 'bottom',
          iconAllowOverlap: true,
          textField: [Expressions.get, 'name'],
          textSize: 11.5,
          textColor: '#0F172A',
          textHaloColor: '#FFFFFF',
          textHaloWidth: 2.2,
          textAnchor: 'bottom',
          textOffset: [0, -3.2],
          textFont: ['Noto Sans Bold'],
          textAllowOverlap: false,
          textOptional: true,
        ),
        filter: ['!', [Expressions.has, 'point_count']],
        enableInteraction: true,
      );

      // Couche du halo de sélection (conforme Étape 5 : rayon 22, transparent centre, blanc 4px sous places-points)
      await c.addGeoJsonSource(selectedSourceId, const {'type': 'FeatureCollection', 'features': []});
      await c.addCircleLayer(
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
      await c.addGeoJsonSource(destinationPinSourceId, const {'type': 'FeatureCollection', 'features': []});
      await c.addCircleLayer(
        destinationPinSourceId,
        destinationPinAuraLayerId,
        const CircleLayerProperties(
          circleColor: '#E53935',
          circleOpacity: 0.25,
          circleRadius: 22.0,
        ),
        enableInteraction: false,
      );
      await c.addCircleLayer(
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
      await c.addSymbolLayer(
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
      await c.addGeoJsonSource(routeSourceId, routeGeoJson);

      // 2.1 Couche de liseré de contraste (blanc en clair, très sombre en nuit)
      await c.addLineLayer(
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
      await c.addLineLayer(
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
      // Boîte tactile confortable autour du doigt pour attraper le pin ou son badge
      final touchBox = Rect.fromCenter(
        center: Offset(point.x, point.y),
        width: 60.0,
        height: 72.0,
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
  Future<List<Map<String, dynamic>>> queryTapFeatures(Point<double> point) async {
    final c = _controller;
    if (c == null || !_layersConfigured) return [];

    try {
      final rect = Rect.fromCenter(
        center: Offset(point.x, point.y),
        width: 48.0,
        height: 48.0,
      );

      final raw = await c.queryRenderedFeaturesInRect(
        rect,
        [placesPointsLayerId, placesClusterLayerId],
        null,
      );

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
          }
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
      return const {
        'type': 'FeatureCollection',
        'features': [],
      };
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
