import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';

/// Type d'entrée dans l'historique de recherche local
enum SearchHistoryKind {
  query, // Terme textuel recherché
  place, // Fiche lieu consultée
  route, // Itinéraire calculé
}

/// Modèle d'élément d'historique local (strictement 0 requête réseau)
class SearchHistoryItem {
  final String id;
  final SearchHistoryKind kind;
  final String label;
  final String? subtitle;
  final String? categorySlug;
  final String? categoryNom;
  final String? icon;
  final String? color;
  final double? latitude;
  final double? longitude;
  final int? placeId;
  final Map<String, dynamic>? routeData;
  final DateTime createdAt;

  const SearchHistoryItem({
    required this.id,
    required this.kind,
    required this.label,
    this.subtitle,
    this.categorySlug,
    this.categoryNom,
    this.icon,
    this.color,
    this.latitude,
    this.longitude,
    this.placeId,
    this.routeData,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'label': label,
        'subtitle': subtitle,
        'categorySlug': categorySlug,
        'categoryNom': categoryNom,
        'icon': icon,
        'color': color,
        'latitude': latitude,
        'longitude': longitude,
        'placeId': placeId,
        'routeData': routeData,
        'createdAt': createdAt.toIso8601String(),
      };

  factory SearchHistoryItem.fromJson(Map<String, dynamic> json) {
    return SearchHistoryItem(
      id: json['id'] as String? ?? UniqueKey().toString(),
      kind: SearchHistoryKind.values.firstWhere(
        (k) => k.name == json['kind'],
        orElse: () => SearchHistoryKind.query,
      ),
      label: json['label'] as String? ?? '',
      subtitle: json['subtitle'] as String?,
      categorySlug: json['categorySlug'] as String?,
      categoryNom: json['categoryNom'] as String?,
      icon: json['icon'] as String?,
      color: json['color'] as String?,
      latitude: (json['latitude'] as num?)?.toDouble(),
      longitude: (json['longitude'] as num?)?.toDouble(),
      placeId: json['placeId'] as int?,
      routeData: json['routeData'] as Map<String, dynamic>?,
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}

/// Service de gestion de l'historique de recherche local.
/// - Limité à 20 entrées maximum.
/// - Déduplication automatique (mise à jour en tête de liste).
/// - Stockage local persistant dans SharedPreferences avec fallback mémoire.
/// - Aucune requête réseau émise.
class SearchHistoryService {
  static const String _storageKey = 'fasonav_search_history_v1';
  static const int maxEntries = 20;
  static int _counter = 0;

  final SharedPreferences? _prefs;
  List<SearchHistoryItem> _memoryCache = [];

  SearchHistoryService([this._prefs]) {
    _loadInitial();
  }

  void _loadInitial() {
    final prefs = _prefs;
    if (prefs != null) {
      try {
        final raw = prefs.getStringList(_storageKey) ?? [];
        _memoryCache = raw.map((itemStr) {
          final map = jsonDecode(itemStr) as Map<String, dynamic>;
          return SearchHistoryItem.fromJson(map);
        }).toList();
      } catch (e) {
        AppLogger.w('Erreur lecture historique recherche local: $e');
        _memoryCache = [];
      }
    }
  }

  /// Récupère la liste ordonnée des recherches récentes (plus récentes d'abord)
  List<SearchHistoryItem> getHistory() {
    return List.unmodifiable(_memoryCache);
  }

  /// Ajoute un mot-clé recherché
  Future<List<SearchHistoryItem>> addQuery(String query) async {
    final clean = query.trim();
    if (clean.isEmpty) return getHistory();

    final current = List<SearchHistoryItem>.from(_memoryCache);
    // Déduplication : retirer l'élément s'il existe déjà
    current.removeWhere(
      (item) =>
          item.kind == SearchHistoryKind.query &&
          item.label.toLowerCase() == clean.toLowerCase(),
    );

    final newItem = SearchHistoryItem(
      id: 'query_${DateTime.now().microsecondsSinceEpoch}_${_counter++}',
      kind: SearchHistoryKind.query,
      label: clean,
      createdAt: DateTime.now(),
    );

    current.insert(0, newItem);
    final capped = current.take(maxEntries).toList();
    await _save(capped);
    return capped;
  }

  /// Ajoute une fiche lieu consultée
  Future<List<SearchHistoryItem>> addPlace(PlaceModel place) async {
    final current = List<SearchHistoryItem>.from(_memoryCache);
    // Déduplication par ID ou nom identique
    current.removeWhere(
      (item) =>
          (item.kind == SearchHistoryKind.place && item.placeId == place.id) ||
          item.label.toLowerCase() == place.nom.toLowerCase(),
    );

    final newItem = SearchHistoryItem(
      id: 'place_${place.id}_${DateTime.now().microsecondsSinceEpoch}_${_counter++}',
      kind: SearchHistoryKind.place,
      label: place.nom,
      subtitle: place.subtitle,
      categorySlug: place.categorie?.slug,
      categoryNom: place.categorie?.nom,
      icon: place.categorie?.icone,
      color: place.categorie?.color,
      latitude: place.latitude,
      longitude: place.longitude,
      placeId: place.id,
      createdAt: DateTime.now(),
    );

    current.insert(0, newItem);
    final capped = current.take(maxEntries).toList();
    await _save(capped);
    return capped;
  }

  /// Ajoute un itinéraire récent (relançable en 1 tap)
  Future<List<SearchHistoryItem>> addRoute({
    required String originName,
    required double originLat,
    required double originLon,
    required String destName,
    required double destLat,
    required double destLon,
    String mode = 'moto',
    List<Map<String, dynamic>> waypoints = const [],
  }) async {
    final current = List<SearchHistoryItem>.from(_memoryCache);
    final label = '$originName ➔ $destName';

    current.removeWhere(
      (item) => item.kind == SearchHistoryKind.route && item.label == label,
    );

    final newItem = SearchHistoryItem(
      id: 'route_${DateTime.now().microsecondsSinceEpoch}_${_counter++}',
      kind: SearchHistoryKind.route,
      label: label,
      subtitle: 'Trajet $mode',
      createdAt: DateTime.now(),
      routeData: {
        'originName': originName,
        'originLat': originLat,
        'originLon': originLon,
        'destName': destName,
        'destLat': destLat,
        'destLon': destLon,
        'mode': mode,
        'waypoints': waypoints,
      },
    );

    current.insert(0, newItem);
    final capped = current.take(maxEntries).toList();
    await _save(capped);
    return capped;
  }

  /// Supprime un élément spécifique de l'historique
  Future<List<SearchHistoryItem>> deleteItem(String id) async {
    final current = List<SearchHistoryItem>.from(_memoryCache);
    current.removeWhere((item) => item.id == id);
    await _save(current);
    return current;
  }

  /// Efface entièrement l'historique local
  Future<void> clearHistory() async {
    _memoryCache = [];
    final prefs = _prefs;
    if (prefs != null) {
      await prefs.remove(_storageKey);
    }
  }

  Future<void> _save(List<SearchHistoryItem> items) async {
    _memoryCache = items;
    final prefs = _prefs;
    if (prefs != null) {
      final raw = items.map((e) => jsonEncode(e.toJson())).toList();
      await prefs.setStringList(_storageKey, raw);
    }
  }
}

/// Provider SharedPreferences optionnel (fallback mémoire si null)
final sharedPreferencesProvider = Provider<SharedPreferences?>((ref) {
  return null;
});

/// Provider du service SearchHistoryService
final searchHistoryServiceProvider = Provider<SearchHistoryService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return SearchHistoryService(prefs);
});

/// Notifier de l'historique de recherche pour réactivité dans l'UI
class SearchHistoryNotifier extends Notifier<List<SearchHistoryItem>> {
  @override
  List<SearchHistoryItem> build() {
    final service = ref.watch(searchHistoryServiceProvider);
    return service.getHistory();
  }

  Future<void> addQuery(String query) async {
    final service = ref.read(searchHistoryServiceProvider);
    state = await service.addQuery(query);
  }

  Future<void> addPlace(PlaceModel place) async {
    final service = ref.read(searchHistoryServiceProvider);
    state = await service.addPlace(place);
  }

  Future<void> addRoute({
    required String originName,
    required double originLat,
    required double originLon,
    required String destName,
    required double destLat,
    required double destLon,
    String mode = 'moto',
    List<Map<String, dynamic>> waypoints = const [],
  }) async {
    final service = ref.read(searchHistoryServiceProvider);
    state = await service.addRoute(
      originName: originName,
      originLat: originLat,
      originLon: originLon,
      destName: destName,
      destLat: destLat,
      destLon: destLon,
      mode: mode,
      waypoints: waypoints,
    );
  }

  Future<void> deleteItem(String id) async {
    final service = ref.read(searchHistoryServiceProvider);
    state = await service.deleteItem(id);
  }

  Future<void> clearHistory() async {
    final service = ref.read(searchHistoryServiceProvider);
    await service.clearHistory();
    state = [];
  }
}

final searchHistoryProvider =
    NotifierProvider<SearchHistoryNotifier, List<SearchHistoryItem>>(
  SearchHistoryNotifier.new,
);
