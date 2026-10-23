import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/data/repositories/places_repository.dart';

/// Couche officielle Mapbox pour les lieux (POI) clusterisés et gros points colorés
/// Conforme à la spécification technique FASO NAV
class PlacesLayer {
  final MapboxMap map;
  bool _isConfigured = false;

  PlacesLayer(this.map);

  Future<void> setup() async {
    try {
      final style = map;
      final sourceExists = await style.styleSourceExists('places');

      if (!sourceExists) {
        await style.addSource(
          GeoJsonSource(
            id: 'places',
            data: '{"type":"FeatureCollection","features":[]}',
            cluster: true,
            clusterRadius: 36,
            clusterMaxZoom: 12,
          ),
        );
      }

      // 1. Grappes de lieux (Clusters)
      if (!await style.styleLayerExists('places-clusters')) {
        await style.addLayer(
          CircleLayer(
            id: 'places-clusters',
            sourceId: 'places',
            filter: ['has', 'point_count'],
            circleColor: 0xFF1E3A5F,
            circleStrokeColor: 0xFFFFFFFF,
            circleStrokeWidth: 3.0,
            circleRadiusExpression: [
              'step',
              ['get', 'point_count'],
              18.0,
              10,
              24.0,
              50,
              32.0,
            ],
          ),
        );
      }

      // 2. Compteur chiffré au centre de chaque grappe
      if (!await style.styleLayerExists('places-cluster-count')) {
        await style.addLayer(
          SymbolLayer(
            id: 'places-cluster-count',
            sourceId: 'places',
            filter: ['has', 'point_count'],
            textFieldExpression: ['get', 'point_count_abbreviated'],
            textColor: 0xFFFFFFFF,
            textSize: 14.0,
          ),
        );
      }

      // 3. Gros points par catégorie (taille interpolée selon zoom et importance)
      if (!await style.styleLayerExists('places-points')) {
        await style.addLayer(
          CircleLayer(
            id: 'places-points',
            sourceId: 'places',
            filter: ['!', ['has', 'point_count']],
            circleColorExpression: ['to-color', ['get', 'color']],
            circleRadiusExpression: [
              'interpolate',
              ['linear'],
              ['zoom'],
              10.0,
              ['*', ['get', 'size'], 2.0],
              16.0,
              ['*', ['get', 'size'], 4.5],
            ],
            circleStrokeColor: 0xFFFFFFFF,
            circleStrokeWidth: 2.5,
          ),
        );
      }

      // 4. Libellés des lieux visibles dès le zoom 11.5
      if (!await style.styleLayerExists('places-labels')) {
        await style.addLayer(
          SymbolLayer(
            id: 'places-labels',
            sourceId: 'places',
            filter: ['!', ['has', 'point_count']],
            minZoom: 11.5,
            textFieldExpression: ['get', 'name'],
            textSize: 12.0,
            textOffset: [0.0, 1.6],
            textColor: 0xFF1B2733,
            textHaloColor: 0xFFFFFFFF,
            textHaloWidth: 1.8,
          ),
        );
      }

      _isConfigured = true;
    } catch (e) {
      AppLogger.w('Configuration PlacesLayer: $e');
    }
  }

  Future<void> show(Map<String, dynamic> featureCollection) async {
    try {
      if (!_isConfigured) {
        await setup();
      }
      final src = await map.getSource('places');
      if (src is GeoJsonSource) {
        await src.updateGeoJSON(jsonEncode(featureCollection));
      }
    } catch (e) {
      AppLogger.w('Mise à jour GeoJSON PlacesLayer: $e');
    }
  }

  Future<void> clear() async {
    await show({'type': 'FeatureCollection', 'features': []});
  }
}

/// Contrôleur gérant la zone visible, le débouncing cameraIdle et les interactions tactiles
class PlacesController extends ChangeNotifier {
  final MapboxMap? map;
  final PlacesLayer layer;
  final PlacesRepository repository;
  final ValueChanged<PlaceModel>? onPlaceSelected;

  final Set<String> _selectedCategories = {};
  Timer? _debounce;
  bool _isLoading = false;
  int _placesCount = 0;
  bool _isDisposed = false;

  PlacesController({
    this.map,
    required this.layer,
    required this.repository,
    this.onPlaceSelected,
  });

  @override
  void notifyListeners() {
    if (!_isDisposed) {
      super.notifyListeners();
    }
  }

  Set<String> get selectedCategories => Set.unmodifiable(_selectedCategories);
  bool get isLoading => _isLoading;
  int get placesCount => _placesCount;

  void setCategories(Set<String> categories) {
    _selectedCategories
      ..clear()
      ..addAll(categories);
    refresh();
    notifyListeners();
  }

  void toggle(String slug) {
    if (_selectedCategories.contains(slug)) {
      _selectedCategories.remove(slug);
    } else {
      _selectedCategories.add(slug);
    }
    refresh();
    notifyListeners();
  }

  void onCameraIdle() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), refresh);
  }

  Future<void> refresh() async {
    if (_isDisposed) return;
    if (_selectedCategories.isEmpty) {
      await layer.clear();
      _placesCount = 0;
      if (!_isDisposed) notifyListeners();
      return;
    }

    try {
      final currentMap = map;
      if (currentMap == null) {
        // Mode hors carte ou test unitaire
        final geoJson = await repository.getPlacesGeoJson(
          categories: _selectedCategories.toList(),
          limit: 800,
        );
        if (_isDisposed) return;
        final features = (geoJson['features'] as List<dynamic>?) ?? [];
        _placesCount = features.length;
        await layer.show(geoJson);
        if (!_isDisposed) notifyListeners();
        return;
      }

      _isLoading = true;
      if (!_isDisposed) notifyListeners();

      final cam = await currentMap.getCameraState();
      final bounds = await currentMap.coordinateBoundsForCamera(
        CameraOptions(center: cam.center, zoom: cam.zoom, bearing: 0.0, pitch: 0.0),
      );

      final swLng = bounds.southwest.coordinates.lng;
      final swLat = bounds.southwest.coordinates.lat;
      final neLng = bounds.northeast.coordinates.lng;
      final neLat = bounds.northeast.coordinates.lat;
      final bbox = '$swLng,$swLat,$neLng,$neLat';

      final geoJson = await repository.getPlacesGeoJson(
        categories: _selectedCategories.toList(),
        bbox: bbox,
        zoom: cam.zoom,
      );

      if (_isDisposed) return;
      final features = (geoJson['features'] as List<dynamic>?) ?? [];
      _placesCount = features.length;

      await layer.show(geoJson);
    } catch (e) {
      AppLogger.w('Erreur rafraîchissement PlacesController: $e');
    } finally {
      if (!_isDisposed) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> showWholeCity(String zone) async {
    if (_selectedCategories.isEmpty) return;

    try {
      _isLoading = true;
      notifyListeners();

      final geoJson = await repository.getPlacesGeoJson(
        categories: _selectedCategories.toList(),
        zone: zone,
        limit: 2000,
      );

      final features = (geoJson['features'] as List<dynamic>?) ?? [];
      _placesCount = features.length;

      await layer.show(geoJson);
    } catch (e) {
      AppLogger.w('showWholeCity PlacesController: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Gère le toucher d'un point ou d'une grappe (queryRenderedFeatures avec boîte tactile)
  Future<bool> handleTap(ScreenCoordinate coordinate) async {
    final currentMap = map;
    if (currentMap == null) return false;

    try {
      final box = ScreenBox(
        min: ScreenCoordinate(x: coordinate.x - 28.0, y: coordinate.y - 28.0),
        max: ScreenCoordinate(x: coordinate.x + 28.0, y: coordinate.y + 28.0),
      );
      final queryGeom = RenderedQueryGeometry.fromScreenBox(box);

      // 1. Vérifier si un point de lieu ou libellé a été touché
      final pointFeatures = await currentMap.queryRenderedFeatures(
        queryGeom,
        RenderedQueryOptions(layerIds: ['places-points', 'places-labels']),
      );

      if (pointFeatures.isNotEmpty && pointFeatures.first != null) {
        final queried = pointFeatures.first!;
        final rawFeature = queried.queriedFeature.feature;
        final place = PlaceModel.fromGeoJsonFeature(rawFeature);
        onPlaceSelected?.call(place);
        return true;
      }

      // 2. Vérifier si une grappe a été touchée : zoomer de 2 niveaux sur son centre
      final clusterFeatures = await currentMap.queryRenderedFeatures(
        queryGeom,
        RenderedQueryOptions(layerIds: ['places-clusters', 'places-cluster-count']),
      );

      if (clusterFeatures.isNotEmpty && clusterFeatures.first != null) {
        final queried = clusterFeatures.first!;
        final rawGeom = queried.queriedFeature.feature['geometry'];
        if (rawGeom is Map) {
          final coords = rawGeom['coordinates'] as List<dynamic>?;
          if (coords != null && coords.length >= 2) {
            final lng = (coords[0] as num).toDouble();
            final lat = (coords[1] as num).toDouble();
            final cam = await currentMap.getCameraState();
            await currentMap.flyTo(
              CameraOptions(
                center: Point(coordinates: Position(lng, lat)),
                zoom: (cam.zoom + 2.0).clamp(1.0, 20.0),
              ),
              MapAnimationOptions(duration: 450),
            );
            return true;
          }
        }
      }
    } catch (e) {
      AppLogger.w('handleTap PlacesController: $e');
    }
    return false;
  }

  @override
  void dispose() {
    _isDisposed = true;
    _debounce?.cancel();
    super.dispose();
  }
}
