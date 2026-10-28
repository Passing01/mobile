import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/data/repositories/places_repository.dart';

/// Couche officielle MapLibre pour les lieux (POI) clusterisés et gros points colorés
class PlacesLayer {
  final MapLibreMapController? controller;
  bool _isConfigured = false;
  Future<void>? _setupFuture;

  PlacesLayer([this.controller]);

  Future<void> setup() async {
    final c = controller;
    if (c == null) return;
    if (_isConfigured) return;
    if (_setupFuture != null) {
      await _setupFuture;
      return;
    }

    final completer = Completer<void>();
    _setupFuture = completer.future;

    try {
      final sources = await c.getSourceIds();
      if (!sources.contains('places')) {
        try {
          await c.addSource(
            'places',
            const GeojsonSourceProperties(
              data: {'type': 'FeatureCollection', 'features': []},
              cluster: true,
              clusterRadius: 36,
              clusterMaxZoom: 12,
            ),
          );
        } catch (e) {
          if (!e.toString().contains('already exists')) rethrow;
        }
      }

      final layers = await c.getLayerIds();
      if (!layers.contains('places-clusters')) {
        try {
          await c.addCircleLayer(
            'places',
            'places-clusters',
            const CircleLayerProperties(
              circleColor: '#1E3A5F',
              circleStrokeColor: '#FFFFFF',
              circleStrokeWidth: 3.0,
              circleRadius: 20.0,
            ),
            filter: ['has', 'point_count'],
          );
        } catch (e) {
          if (!e.toString().contains('already exists')) rethrow;
        }
      }

      if (!layers.contains('places-cluster-count')) {
        try {
          await c.addSymbolLayer(
            'places',
            'places-cluster-count',
            const SymbolLayerProperties(
              textField: [Expressions.get, 'point_count_abbreviated'],
              textColor: '#FFFFFF',
              textSize: 14.0,
            ),
            filter: ['has', 'point_count'],
          );
        } catch (e) {
          if (!e.toString().contains('already exists')) rethrow;
        }
      }

      if (!layers.contains('places-points')) {
        try {
          await c.addCircleLayer(
            'places',
            'places-points',
            const CircleLayerProperties(
              circleColor: [Expressions.get, 'color'],
              circleStrokeColor: '#FFFFFF',
              circleStrokeWidth: 2.0,
              circleRadius: 8.0,
            ),
            filter: ['!', ['has', 'point_count']],
          );
        } catch (e) {
          if (!e.toString().contains('already exists')) rethrow;
        }
      }

      _isConfigured = true;
    } catch (e) {
      AppLogger.w('Configuration PlacesLayer MapLibre: $e');
    } finally {
      completer.complete();
    }
  }

  Future<void> show(Map<String, dynamic> featureCollection) async {
    final c = controller;
    if (c == null) return;
    try {
      if (!_isConfigured) {
        await setup();
      }
      await c.setGeoJsonSource('places', featureCollection);
    } catch (e) {
      AppLogger.w('Mise à jour GeoJSON PlacesLayer: $e');
    }
  }

  Future<void> clear() async {
    await show({'type': 'FeatureCollection', 'features': []});
  }
}

/// Contrôleur gérant la zone visible, le multi-filtrage et les interactions tactiles
class PlacesController extends ChangeNotifier {
  final MapLibreMapController? map;
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

      final bounds = await currentMap.getVisibleRegion();
      final swLng = bounds.southwest.longitude;
      final swLat = bounds.southwest.latitude;
      final neLng = bounds.northeast.longitude;
      final neLat = bounds.northeast.latitude;
      final bbox = '$swLng,$swLat,$neLng,$neLat';

      final geoJson = await repository.getPlacesGeoJson(
        categories: _selectedCategories.toList(),
        bbox: bbox,
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

  /// Gère le toucher d'un point ou d'une grappe
  Future<bool> handleTap(Point<double> point) async {
    final currentMap = map;
    if (currentMap == null) return false;

    try {
      final features = await currentMap.queryRenderedFeatures(
        point,
        ['places-points', 'places-clusters'],
        null,
      );

      if (features.isNotEmpty && features.first != null) {
        final feature = features.first;
        if (feature is Map) {
          final props = feature['properties'] as Map?;
          if (props != null && props.containsKey('point_count')) {
            final geom = feature['geometry'] as Map?;
            final coords = geom?['coordinates'] as List?;
            if (coords != null && coords.length >= 2) {
              final lng = (coords[0] as num).toDouble();
              final lat = (coords[1] as num).toDouble();
              await currentMap.animateCamera(
                CameraUpdate.newLatLngZoom(LatLng(lat, lng), 14.5),
              );
              return true;
            }
          } else {
            final place = PlaceModel.fromGeoJsonFeature(Map<String, dynamic>.from(feature));
            onPlaceSelected?.call(place);
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
