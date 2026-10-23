import 'dart:convert';
import 'dart:math' as math;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qvgestion_mobile/core/config/app_config.dart';
import 'package:qvgestion_mobile/core/errors/app_error_reporter.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/places/data/models/category_model.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';

/// Repository pour interagir avec les endpoints réels de catégories et lieux (POI)
/// avec support du cache local hors-ligne (SharedPreferences)
class PlacesRepository {
  final ApiClient apiClient;
  static const String _placesCacheKey = 'qvgestion_cached_places_v1';

  PlacesRepository({required this.apiClient});

  double _calculateDistanceMeters(double lat1, double lon1, double lat2, double lon2) {
    const earthRadius = 6371000.0;
    final dLat = (lat2 - lat1) * math.pi / 180.0;
    final dLon = (lon2 - lon1) * math.pi / 180.0;
    final a = math.sin(dLat / 2) * math.sin(dLat / 2) +
        math.cos(lat1 * math.pi / 180.0) *
            math.cos(lat2 * math.pi / 180.0) *
            math.sin(dLon / 2) *
            math.sin(dLon / 2);
    final c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a));
    return earthRadius * c;
  }

  Future<void> _savePlacesToCache(List<PlaceModel> places) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final existingJson = prefs.getStringList(_placesCacheKey) ?? [];
      final existingPlaces = <int, PlaceModel>{};
      for (final raw in existingJson) {
        try {
          final p = PlaceModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
          existingPlaces[p.id] = p;
        } catch (e) {
          AppLogger.w('Format de lieu en cache invalide ignoré: $e');
        }
      }
      for (final p in places) {
        existingPlaces[p.id] = p;
      }
      final toSave =
          existingPlaces.values.map((p) => jsonEncode(p.toJson())).toList();
      await prefs.setStringList(_placesCacheKey, toSave);
    } catch (e) {
      AppLogger.w('Impossible d\'écrire les lieux dans le cache: $e');
    }
  }

  Future<List<PlaceModel>> _getCachedPlaces() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final list = prefs.getStringList(_placesCacheKey) ?? [];
      final places = <PlaceModel>[];
      for (final str in list) {
        try {
          places.add(PlaceModel.fromJson(jsonDecode(str) as Map<String, dynamic>));
        } catch (e) {
          AppLogger.w('Erreur décodage lieu en cache: $e');
        }
      }
      return places;
    } catch (e) {
      AppLogger.w('Impossible de lire le cache de lieux: $e');
      return [];
    }
  }

  /// Récupère toutes les catégories de lieux depuis GET /api/v1/categories/
  Future<List<CategoryModel>> getCategories() async {
    try {
      final response = await apiClient.get<dynamic>(ApiEndpoints.categories);
      final list = response.data as List<dynamic>;
      final categories = list
          .map((item) => CategoryModel.fromJson(item as Map<String, dynamic>))
          .toList();
      return categories.isNotEmpty ? categories : defaultOuagaCategories;
    } catch (e) {
      AppLogger.w('Catégories distantes inaccessibles ($e). Utilisation du catalogue local par défaut.');
      return defaultOuagaCategories;
    }
  }

  /// Récupère les lieux filtrés par catégories, bbox, zone ou near en GeoJSON (FeatureCollection)
  /// Conforme à la spécification FASO NAV: GET /api/v1/places?categories=...&bbox=...
  Future<Map<String, dynamic>> getPlacesGeoJson({
    required List<String> categories,
    String? bbox,
    String? zone,
    double? lat,
    double? lng,
    double? radiusM,
    String? q,
    double zoom = 14.0,
    int limit = 800,
  }) async {
    final sortedCats = List<String>.from(categories)..sort();
    final cacheKey = 'geojson_${sortedCats.join("_")}_${zone ?? bbox ?? "${lat}_$lng"}';
    try {
      final queryParams = <String, dynamic>{
        'categories': categories.join(','),
        'limit': limit,
        'zoom': zoom,
      };
      if (bbox != null) queryParams['bbox'] = bbox;
      if (zone != null) queryParams['zone'] = zone;
      if (lat != null && lng != null) {
        queryParams['near'] = '$lat,$lng';
        if (radiusM != null) queryParams['radius_m'] = radiusM.round();
      }
      if (q != null && q.isNotEmpty) queryParams['q'] = q;

      final response = await apiClient.get<dynamic>(
        ApiEndpoints.places,
        queryParameters: queryParams,
      );

      final data = response.data;
      if (data is Map && data['type'] == 'FeatureCollection') {
        final features = (data['features'] as List<dynamic>?) ?? [];
        if (features.isNotEmpty) {
          try {
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString(cacheKey, jsonEncode(data));
          } catch (e) {
            AppLogger.w('Impossible de mettre en cache les lieux: $e');
          }
          final map = <String, dynamic>{};
          data.forEach((k, v) => map[k.toString()] = v);
          return map;
        }
      }

      // Si l'API retourne 0 points dans cette zone, injecter les repères locaux uniquement en mode test
      if (AppConfig.testMode) {
        final localFeatures = _buildLocalFallbackFeatures(categories);
        if (localFeatures.isNotEmpty) {
          return {
            'type': 'FeatureCollection',
            'features': localFeatures,
          };
        }
      }
      return {'type': 'FeatureCollection', 'features': []};
    } catch (e, st) {
      AppErrorReporter.reportError(
        'Erreur GeoJSON lieux API',
        error: e,
        stackTrace: st,
        tag: 'PlacesAPI',
      );
      try {
        final prefs = await SharedPreferences.getInstance();
        final raw = prefs.getString(cacheKey);
        if (raw != null) {
          final decoded = jsonDecode(raw) as Map<String, dynamic>;
          if (decoded['features'] is List && (decoded['features'] as List).isNotEmpty) {
            return decoded;
          }
        }
      } catch (cacheErr) {
        AppLogger.w('Lecture cache GeoJSON impossible: $cacheErr');
      }

      if (AppConfig.testMode) {
        return {
          'type': 'FeatureCollection',
          'features': _buildLocalFallbackFeatures(categories),
        };
      }
      return {'type': 'FeatureCollection', 'features': []};
    }
  }

  List<Map<String, dynamic>> _buildLocalFallbackFeatures(List<String> categories) {
    final features = <Map<String, dynamic>>[];
    final catSet = categories.map((c) => c.toLowerCase()).toSet();

    for (final p in defaultOuagaIconicPlaces) {
      final slug = (p.categorie?.slug ?? '').toLowerCase();
      final nom = p.nom.toLowerCase();
      final matchesCat = catSet.isEmpty ||
          catSet.contains(slug) ||
          (catSet.contains('pharmacie') && (slug.contains('pharmacie') || nom.contains('pharmacie'))) ||
          ((catSet.contains('station-service') || catSet.contains('station')) &&
              (slug.contains('station') || nom.contains('station') || nom.contains('total') || nom.contains('shell'))) ||
          ((catSet.contains('hopital-sante') || catSet.contains('hopital')) &&
              (slug.contains('hopital') || nom.contains('chuy') || nom.contains('yalgado') || nom.contains('cma') || nom.contains('clinique'))) ||
          ((catSet.contains('maquis-restaurant') || catSet.contains('maquis')) &&
              (slug.contains('maquis') || slug.contains('restaurant') || nom.contains('maquis')));
      if (matchesCat) {
        features.add(p.toGeoJsonFeature());
      }
    }
    return features;
  }

  /// Récupère les lieux à proximité (autour de moi) depuis GET /api/v1/places/nearby
  /// avec sauvegarde automatique hors-ligne et calcul de distance
  Future<List<PlaceModel>> getNearbyPlaces({
    required double lat,
    required double lon,
    double radius = 10000.0,
    int? categorieId,
    String? slug,
    int limit = 30,
  }) async {
    List<PlaceModel> fetched = [];
    try {
      final queryParams = <String, dynamic>{
        'lat': lat,
        'lon': lon,
        'radius': radius,
        'limit': limit,
      };
      if (categorieId != null) {
        queryParams['categorie_id'] = categorieId;
      }
      if (slug != null && slug.isNotEmpty) {
        queryParams['slug'] = slug;
      }

      final response = await apiClient.get<dynamic>(
        ApiEndpoints.placesNearby,
        queryParameters: queryParams,
      );

      final list = response.data as List<dynamic>;
      fetched = list
          .map((item) => PlaceModel.fromJson(item as Map<String, dynamic>))
          .toList();

      if (fetched.isNotEmpty) {
        await _savePlacesToCache(fetched);
      }
      return fetched;
    } catch (e, st) {
      AppErrorReporter.reportError(
        'Erreur de récupération des lieux proches',
        error: e,
        stackTrace: st,
        tag: 'PlacesAPI',
      );
      // En mode hors-ligne, récupérer le cache sauvegardé et fusionner avec le catalogue si mode test
      final cached = await _getCachedPlaces();
      final allMap = <int, PlaceModel>{};

      if (AppConfig.testMode) {
        for (final p in defaultOuagaIconicPlaces) {
          allMap[p.id] = p;
        }
      }
      for (final p in cached) {
        allMap[p.id] = p;
      }

      final results = <PlaceModel>[];
      for (final p in allMap.values) {
        if (slug != null && slug.isNotEmpty) {
          final pSlug = p.categorie?.slug.toLowerCase() ?? '';
          final nomLower = p.nom.toLowerCase();
          if (slug == 'pharmacie' &&
              (!pSlug.contains('pharmacie') && !nomLower.contains('pharmacie'))) {
            continue;
          } else if (slug != 'pharmacie' &&
              pSlug != slug &&
              !nomLower.contains(slug)) {
            continue;
          }
        }

        final dist = _calculateDistanceMeters(lat, lon, p.latitude, p.longitude);
        if (dist <= radius || slug != null) {
          results.add(p.copyWith(distanceMeters: dist));
        }
      }

      results.sort((a, b) =>
          (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
      return results;
    }
  }

  /// Recherche des lieux par mot-clé depuis GET /api/v1/places/search
  /// avec cache local, tolérance hors-ligne et calcul de proximité
  Future<List<PlaceModel>> searchPlaces({
    required String query,
    double? currentLat,
    double? currentLon,
    String? ville,
    String? quartier,
    int? categorieId,
    int limit = 20,
  }) async {
    final q = query.trim().toLowerCase();
    List<PlaceModel> fetched = [];

    try {
      final queryParams = <String, dynamic>{
        'q': query.trim(),
        'limit': limit,
      };
      if (ville != null && ville.isNotEmpty) {
        queryParams['ville'] = ville;
      }
      if (quartier != null && quartier.isNotEmpty) {
        queryParams['quartier'] = quartier;
      }
      if (categorieId != null) {
        queryParams['categorie_id'] = categorieId;
      }

      final response = await apiClient.get<dynamic>(
        ApiEndpoints.placesSearch,
        queryParameters: queryParams,
      );

      final list = response.data as List<dynamic>;
      fetched = list
          .map((item) => PlaceModel.fromJson(item as Map<String, dynamic>))
          .toList();

      if (fetched.isNotEmpty) {
        await _savePlacesToCache(fetched);
      }

      // Enrichir avec les distances exactes si coordonnées disponibles
      if (currentLat != null && currentLon != null) {
        return fetched.map((p) {
          final dist = _calculateDistanceMeters(
              currentLat, currentLon, p.latitude, p.longitude);
          return p.copyWith(distanceMeters: dist);
        }).toList()
          ..sort((a, b) =>
              (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
      }
      return fetched;
    } catch (e, st) {
      AppErrorReporter.reportError(
        'Erreur lors de la recherche de lieux',
        error: e,
        stackTrace: st,
        tag: 'PlacesAPI',
      );
      final cached = await _getCachedPlaces();
      final allMap = <int, PlaceModel>{};

      if (AppConfig.testMode) {
        for (final p in defaultOuagaIconicPlaces) {
          allMap[p.id] = p;
        }
      }
      for (final p in cached) {
        allMap[p.id] = p;
      }

      final results = <PlaceModel>[];
      for (final p in allMap.values) {
        final nom = p.nom.toLowerCase();
        final desc = (p.description ?? '').toLowerCase();
        final quart = (p.quartier ?? '').toLowerCase();
        final cat = (p.categorie?.nom ?? '').toLowerCase();
        final slug = (p.categorie?.slug ?? '').toLowerCase();

        final matches = nom.contains(q) ||
            desc.contains(q) ||
            quart.contains(q) ||
            cat.contains(q) ||
            slug.contains(q);

        if (matches) {
          if (currentLat != null && currentLon != null) {
            final dist = _calculateDistanceMeters(
                currentLat, currentLon, p.latitude, p.longitude);
            results.add(p.copyWith(distanceMeters: dist));
          } else {
            results.add(p);
          }
        }
      }

      if (currentLat != null && currentLon != null) {
        results.sort((a, b) =>
            (a.distanceMeters ?? 0).compareTo(b.distanceMeters ?? 0));
      }

      return results;
    }
  }

  /// Récupère le détail d'un lieu d'intérêt depuis GET /api/v1/places/{id}
  Future<PlaceModel> getPlaceDetail(int placeId) async {
    try {
      final response = await apiClient.get<dynamic>(ApiEndpoints.placeDetail(placeId));
      return PlaceModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      AppLogger.e('Erreur lors de la récupération du lieu #$placeId: $e');
      rethrow;
    }
  }

  /// Ajoute ou retire un lieu des favoris utilisateur
  Future<bool> toggleFavorite({
    required int placeId,
    required bool isCurrentlyFavorite,
    String? alias,
  }) async {
    try {
      if (isCurrentlyFavorite) {
        await apiClient.delete<dynamic>(ApiEndpoints.removeFavorite(placeId));
        return false;
      } else {
        await apiClient.post<dynamic>(
          ApiEndpoints.placeFavorite(placeId),
          data: {
            'lieu_id': placeId,
            'alias': ?alias,
          },
        );
        return true;
      }
    } catch (e) {
      AppLogger.e('Erreur lors de la bascule favori pour le lieu #$placeId: $e');
      rethrow;
    }
  }

  /// Création participative d'un lieu depuis POST /api/v1/places/
  Future<PlaceModel> createPlace(Map<String, dynamic> placeData) async {
    try {
      final response = await apiClient.post<dynamic>(
        ApiEndpoints.places,
        data: placeData,
      );
      return PlaceModel.fromJson(response.data as Map<String, dynamic>);
    } catch (e) {
      AppLogger.e('Erreur lors de la création du lieu: $e');
      rethrow;
    }
  }
}
