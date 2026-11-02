import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qvgestion_mobile/core/config/app_constants.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
import 'package:qvgestion_mobile/core/services/location_service.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/places/data/models/category_model.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/data/repositories/places_repository.dart';

/// Provider du repository des lieux & catégories réels
final placesRepositoryProvider = Provider<PlacesRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  return PlacesRepository(apiClient: apiClient);
});

/// Provider de la liste des catégories retournées par le backend
final categoriesProvider = FutureProvider<List<CategoryModel>>((ref) async {
  final repository = ref.watch(placesRepositoryProvider);
  return repository.getCategories();
});

/// Gestionnaire de la sélection MULTIPLE de catégories (conforme à FASO NAV)
class SelectedCategories extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggle(String slug) {
    final next = {...state};
    next.contains(slug) ? next.remove(slug) : next.add(slug);
    state = next;
  }

  void toggleCategory(String slug) => toggle(slug);

  void selectCategory(String? slug) {
    if (slug == null) {
      clear();
    } else {
      toggle(slug);
    }
  }

  void selectOnly(String slug) {
    if (state.length == 1 && state.contains(slug)) {
      clear();
    } else {
      state = {slug};
    }
  }

  void clear() {
    state = {};
  }
}

final selectedCategoriesProvider =
    NotifierProvider<SelectedCategories, Set<String>>(
  SelectedCategories.new,
);

/// Bounding box courante de la carte (format: 'lng0,lat0,lng1,lat1')
class MapBoundingBoxNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void updateBoundingBox(String? bbox) {
    state = bbox;
  }
}

final mapBoundingBoxProvider =
    NotifierProvider<MapBoundingBoxNotifier, String?>(
  MapBoundingBoxNotifier.new,
);

/// Provider GeoJSON des lieux de la zone visible selon les catégories cochées (ou tous les lieux si aucun filtre)
final placesGeoJsonProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final selectedCats = ref.watch(selectedCategoriesProvider);
  final repo = ref.watch(placesRepositoryProvider);
  final bbox = ref.watch(mapBoundingBoxProvider);
  final loc = ref.watch(currentLocationProvider);

  return repo.getPlacesGeoJson(
    categories: selectedCats.isNotEmpty ? selectedCats.toList() : null,
    bbox: bbox,
    lat: loc.lat,
    lng: loc.lon,
  );
});

/// État des lieux chargés pour la zone visible (conforme Étape 4)
class PlacesState extends Equatable {
  final bool isLoading;
  final int count;
  final String? categoryLabel;
  final String? errorMessage;
  final bool hasError;
  final bool isZero;
  final bool truncated;
  final bool isOffline;
  final Map<String, dynamic> lastGeoJson;
  final List<PlaceModel> placesList;

  const PlacesState({
    this.isLoading = false,
    this.count = 0,
    this.categoryLabel,
    this.errorMessage,
    this.hasError = false,
    this.isZero = false,
    this.truncated = false,
    this.isOffline = false,
    this.lastGeoJson = const {'type': 'FeatureCollection', 'features': []},
    this.placesList = const [],
  });

  factory PlacesState.initial() => const PlacesState();

  factory PlacesState.ok({
    required int count,
    required Map<String, dynamic> geoJson,
    required List<PlaceModel> places,
    String? categoryLabel,
    bool truncated = false,
    bool isOffline = false,
  }) =>
      PlacesState(
        isLoading: false,
        count: count,
        isZero: count == 0,
        hasError: false,
        truncated: truncated,
        isOffline: isOffline,
        lastGeoJson: geoJson,
        placesList: places,
        categoryLabel: categoryLabel,
      );

  factory PlacesState.error(
    String message, {
    required Map<String, dynamic> previousGeoJson,
    required List<PlaceModel> previousPlaces,
    int previousCount = 0,
    String? categoryLabel,
    bool truncated = false,
    bool isOffline = false,
  }) =>
      PlacesState(
        isLoading: false,
        count: previousCount,
        errorMessage: message,
        hasError: true,
        isZero: false,
        truncated: truncated,
        isOffline: isOffline,
        lastGeoJson: previousGeoJson,
        placesList: previousPlaces,
        categoryLabel: categoryLabel,
      );

  factory PlacesState.loading({
    required Map<String, dynamic> previousGeoJson,
    required List<PlaceModel> previousPlaces,
    int previousCount = 0,
    String? categoryLabel,
    bool truncated = false,
    bool isOffline = false,
  }) =>
      PlacesState(
        isLoading: true,
        count: previousCount,
        truncated: truncated,
        isOffline: isOffline,
        lastGeoJson: previousGeoJson,
        placesList: previousPlaces,
        categoryLabel: categoryLabel,
      );

  @override
  List<Object?> get props => [
        isLoading,
        count,
        categoryLabel,
        errorMessage,
        hasError,
        isZero,
        truncated,
        isOffline,
        lastGeoJson,
        placesList,
      ];
}

class PlacesNotifier extends Notifier<PlacesState> {
  @override
  PlacesState build() => PlacesState.initial();

  void setLoading() {
    state = PlacesState.loading(
      previousGeoJson: state.lastGeoJson,
      previousPlaces: state.placesList,
      previousCount: state.count,
      categoryLabel: state.categoryLabel,
      truncated: state.truncated,
      isOffline: state.isOffline,
    );
  }

  void setOk({
    required int count,
    required Map<String, dynamic> geoJson,
    required List<PlaceModel> places,
    String? categoryLabel,
    bool truncated = false,
    bool isOffline = false,
  }) {
    state = PlacesState.ok(
      count: count,
      geoJson: geoJson,
      places: places,
      categoryLabel: categoryLabel,
      truncated: truncated,
      isOffline: isOffline,
    );
  }

  void setError(String message) {
    state = PlacesState.error(
      message,
      previousGeoJson: state.lastGeoJson,
      previousPlaces: state.placesList,
      previousCount: state.count,
      categoryLabel: state.categoryLabel,
      truncated: state.truncated,
      isOffline: state.isOffline,
    );
  }

  void clear() {
    state = PlacesState.initial();
  }
}

final placesStateProvider = NotifierProvider<PlacesNotifier, PlacesState>(
  PlacesNotifier.new,
);

/// Compteur dynamique de lieux chargés
final placesCountProvider = Provider<int>((ref) {
  final placesState = ref.watch(placesStateProvider);
  if (placesState.count > 0 || placesState.hasError || placesState.isZero) {
    return placesState.count;
  }
  final geoJson = ref.watch(placesGeoJsonProvider).value;
  if (geoJson == null) return 0;
  final features = geoJson['features'] as List<dynamic>?;
  return features?.length ?? 0;
});

/// État de la géolocalisation actuelle de l'utilisateur
class LocationState extends Equatable {
  final double lat;
  final double lon;
  final String label;

  const LocationState({
    required this.lat,
    required this.lon,
    this.label = 'Ma position',
  });

  @override
  List<Object?> get props => [lat, lon, label];
}

class CurrentLocationNotifier extends Notifier<LocationState> {
  StreamSubscription<Position>? _positionStreamSub;

  @override
  LocationState build() {
    ref.onDispose(() {
      _positionStreamSub?.cancel();
    });
    final locService = ref.read(locationServiceProvider);
    final lastPos = locService.last;
    if (lastPos != null && locService.isUsable(lastPos)) {
      return LocationState(
        lat: lastPos.latitude,
        lon: lastPos.longitude,
        label: 'Ma position GPS',
      );
    }
    return const LocationState(
      lat: AppConstants.ouagaCenterLatitude,
      lon: AppConstants.ouagaCenterLongitude,
      label: 'Ouagadougou',
    );
  }

  void updateLocation(double lat, double lon, [String? label]) {
    final prev = state;
    final isPrevDefault = (prev.lat - AppConstants.ouagaCenterLatitude).abs() < 1e-5 &&
        (prev.lon - AppConstants.ouagaCenterLongitude).abs() < 1e-5;
    if (!isPrevDefault) {
      final dLat = (lat - prev.lat) * 111000.0;
      final dLon = (lon - prev.lon) * 108000.0;
      final distSq = dLat * dLat + dLon * dLon;
      // Ignore micro-bruit thermique GPS stationnaire (< 4 mètres)
      if (distSq < 16.0 && (label == null || label == prev.label)) {
        return;
      }
    }
    state = LocationState(
      lat: lat,
      lon: lon,
      label: label ?? 'Position actuelle',
    );
  }

  /// Récupère la position GPS réelle du smartphone de l'utilisateur via LocationService
  Future<void> fetchRealDeviceLocation() async {
    try {
      final locService = ref.read(locationServiceProvider);
      final status = await locService.ensurePermission();
      if (status == LocationStatus.ok) {
        await locService.start();
        _positionStreamSub?.cancel();
        _positionStreamSub = locService.stream.listen((pos) {
          if (!locService.isUsable(pos)) return;
          state = LocationState(
            lat: pos.latitude,
            lon: pos.longitude,
            label: 'Position GPS précise',
          );
        });

        if (locService.last != null && locService.isUsable(locService.last!)) {
          final p = locService.last!;
          state = LocationState(
            lat: p.latitude,
            lon: p.longitude,
            label: 'Ma position GPS',
          );
        }
      }
    } catch (e) {
      AppLogger.w('[GPS] Erreur initialisation position: $e');
    }
  }
}

final currentLocationProvider =
    NotifierProvider<CurrentLocationNotifier, LocationState>(
  CurrentLocationNotifier.new,
);

/// Catalogue exhaustif de secours des lieux clés de Ouagadougou
const List<PlaceModel> defaultOuagaIconicPlaces = [
  PlaceModel(
    id: 1,
    nom: 'Pharmacie du 1200 Logements',
    description: 'Pharmacie de garde 24h/24, accessible en deux-roues',
    categorieId: 1,
    latitude: 12.3688,
    longitude: -1.4988,
    ville: 'Ouagadougou',
    quartier: '1200 Logements',
    telephone: '+22625360000',
    horaires: '24h/24',
    distanceMeters: 0,
    tags: {'de_garde': true},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 2,
    nom: 'Total Échangeur de l\'Est',
    description: 'Station-service avec gonflage deux-roues et boutique 24h/24',
    categorieId: 2,
    latitude: 12.3610,
    longitude: -1.4850,
    ville: 'Ouagadougou',
    quartier: 'Dassasgho',
    telephone: '+22625300000',
    horaires: '24h/24',
    distanceMeters: 1730,
    categorie: CategoryModel(id: 2, nom: 'Station-service', slug: 'station-service', icone: 'local_gas_station'),
  ),
  PlaceModel(
    id: 3,
    nom: 'Maquis Le Festival',
    description: 'Grillades de poulet bicyclette et rafraîchissements',
    categorieId: 3,
    latitude: 12.3695,
    longitude: -1.4975,
    ville: 'Ouagadougou',
    quartier: '1200 Logements',
    telephone: '+22670112233',
    horaires: '16h - 02h',
    distanceMeters: 160,
    categorie: CategoryModel(id: 3, nom: 'Maquis / Resto', slug: 'maquis-restaurant', icone: 'restaurant'),
  ),
  PlaceModel(
    id: 4,
    nom: 'Grand Marché Rood-Woko',
    description: 'Grand marché central et pôle commercial historique',
    categorieId: 8,
    latitude: 12.3685,
    longitude: -1.5222,
    ville: 'Ouagadougou',
    quartier: 'Centre-Ville',
    horaires: '07h - 18h',
    distanceMeters: 2540,
    categorie: CategoryModel(id: 8, nom: 'Marché / Commerce', slug: 'marche-commerce', icone: 'storefront'),
  ),
  PlaceModel(
    id: 5,
    nom: 'Hôpital Yalgado Ouédraogo (CHU-YO)',
    description: 'Centre Hospitalier Universitaire et Urgences',
    categorieId: 4,
    latitude: 12.3800,
    longitude: -1.5050,
    ville: 'Ouagadougou',
    quartier: 'Dapoya',
    telephone: '+22625311655',
    horaires: '24h/24',
    distanceMeters: 1415,
    categorie: CategoryModel(id: 4, nom: 'Hôpital / Urgences', slug: 'hopital-sante', icone: 'local_hospital'),
  ),
  PlaceModel(
    id: 6,
    nom: 'Monument des Héros Nationaux',
    description: 'Monument historique majeur et symbole de Ouaga 2000',
    categorieId: 5,
    latitude: 12.3160,
    longitude: -1.5030,
    ville: 'Ouagadougou',
    quartier: 'Ouaga 2000',
    horaires: '08h - 18h',
    distanceMeters: 5900,
    categorie: CategoryModel(id: 5, nom: 'Administration', slug: 'administration', icone: 'account_balance'),
  ),
  PlaceModel(
    id: 7,
    nom: 'Place de la Nation (Révolution)',
    description: 'Cœur civique et rassemblement historique',
    categorieId: 5,
    latitude: 12.3680,
    longitude: -1.5270,
    ville: 'Ouagadougou',
    quartier: 'Centre-Ville',
    distanceMeters: 3100,
    categorie: CategoryModel(id: 5, nom: 'Administration', slug: 'administration', icone: 'flag'),
  ),
  PlaceModel(
    id: 8,
    nom: 'Université Joseph Ki-Zerbo',
    description: 'Campus principal universitaire de Zogona',
    categorieId: 7,
    latitude: 12.3760,
    longitude: -1.5010,
    ville: 'Ouagadougou',
    quartier: 'Zogona',
    horaires: '07h - 20h',
    distanceMeters: 850,
    categorie: CategoryModel(id: 7, nom: 'École & Université', slug: 'ecole-universite', icone: 'school'),
  ),
  PlaceModel(
    id: 9,
    nom: 'SIAO (Salon de l\'Artisanat)',
    description: 'Grand parc d\'exposition et artisanat d\'Afrique',
    categorieId: 5,
    latitude: 12.3480,
    longitude: -1.4920,
    ville: 'Ouagadougou',
    quartier: 'Wemtenga',
    distanceMeters: 2400,
    categorie: CategoryModel(id: 5, nom: 'Administration', slug: 'administration', icone: 'palette'),
  ),
  PlaceModel(
    id: 10,
    nom: 'Total Patte d\'Oie',
    description: 'Station essence, boutique et gonflage pneu moto',
    categorieId: 2,
    latitude: 12.3350,
    longitude: -1.5210,
    ville: 'Ouagadougou',
    quartier: 'Patte d\'Oie',
    telephone: '+22625370011',
    horaires: '24h/24',
    distanceMeters: 4400,
    categorie: CategoryModel(id: 2, nom: 'Station-service', slug: 'station-service', icone: 'local_gas_station'),
  ),
  PlaceModel(
    id: 11,
    nom: 'Pharmacie Trypano Gounghin',
    description: 'Grande officine de garde accessible sur l\'axe Gounghin',
    categorieId: 1,
    latitude: 12.3580,
    longitude: -1.5420,
    ville: 'Ouagadougou',
    quartier: 'Gounghin',
    telephone: '+22625341234',
    horaires: '24h/24',
    distanceMeters: 4800,
    tags: {'de_garde': true},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 12,
    nom: 'Mémorial Thomas Sankara',
    description: 'Statue et mémorial au Conseil de l\'Entente',
    categorieId: 5,
    latitude: 12.3615,
    longitude: -1.5110,
    ville: 'Ouagadougou',
    quartier: 'Koulouba',
    horaires: '08h - 17h',
    distanceMeters: 1550,
    categorie: CategoryModel(id: 5, nom: 'Administration', slug: 'administration', icone: 'museum'),
  ),
  PlaceModel(
    id: 13,
    nom: 'Pharmacie Yennenga',
    description: 'Pharmacie de garde au cœur de la ville, service 24h/24',
    categorieId: 1,
    latitude: 12.3712,
    longitude: -1.5180,
    ville: 'Ouagadougou',
    quartier: 'Centre-Ville',
    telephone: '+22625306641',
    horaires: '24h/24',
    distanceMeters: 2100,
    tags: {'de_garde': true},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 14,
    nom: 'Pharmacie Keneyaso',
    description: 'Officine de garde accessible axe Charles de Gaulle',
    categorieId: 1,
    latitude: 12.3550,
    longitude: -1.4930,
    ville: 'Ouagadougou',
    quartier: 'Wemtenga',
    telephone: '+22625362020',
    horaires: '24h/24',
    distanceMeters: 1800,
    tags: {'de_garde': true},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 15,
    nom: 'Pharmacie de la Paix',
    description: 'Pharmacie de garde Somgandé avec parking deux-roues',
    categorieId: 1,
    latitude: 12.3850,
    longitude: -1.5020,
    ville: 'Ouagadougou',
    quartier: 'Somgandé',
    telephone: '+22625350033',
    horaires: '24h/24',
    distanceMeters: 2400,
    tags: {'de_garde': true},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 16,
    nom: 'Pharmacie Fraternité',
    description: 'Pharmacie de garde zone Sud / Cissin',
    categorieId: 1,
    latitude: 12.3420,
    longitude: -1.5380,
    ville: 'Ouagadougou',
    quartier: 'Cissin',
    telephone: '+22625430101',
    horaires: '24h/24',
    distanceMeters: 3900,
    tags: {'de_garde': true},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 17,
    nom: 'Pharmacie Saint-Bernard',
    description: 'Grande officine de garde au rond-point Tampouy',
    categorieId: 1,
    latitude: 12.3920,
    longitude: -1.5510,
    ville: 'Ouagadougou',
    quartier: 'Tampouy',
    telephone: '+22625370202',
    horaires: '24h/24',
    distanceMeters: 5100,
    tags: {'de_garde': true},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 18,
    nom: 'Pharmacie Ouaga 2000',
    description: 'Pharmacie de garde moderne boulevard Muammar Kadhafi',
    categorieId: 1,
    latitude: 12.3210,
    longitude: -1.5120,
    ville: 'Ouagadougou',
    quartier: 'Ouaga 2000',
    telephone: '+22625374444',
    horaires: '24h/24',
    distanceMeters: 5400,
    tags: {'de_garde': true},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 19,
    nom: 'Shell Koulouba',
    description: 'Station-service, lubrifiants et boutique 24h/24',
    categorieId: 2,
    latitude: 12.3660,
    longitude: -1.5190,
    ville: 'Ouagadougou',
    quartier: 'Koulouba',
    telephone: '+22625310000',
    horaires: '24h/24',
    distanceMeters: 2300,
    categorie: CategoryModel(id: 2, nom: 'Station-service', slug: 'station-service', icone: 'local_gas_station'),
  ),
  PlaceModel(
    id: 20,
    nom: 'Total Tampouy',
    description: 'Carburant et gonflage pneus deux-roues 24h/24',
    categorieId: 2,
    latitude: 12.3880,
    longitude: -1.5450,
    ville: 'Ouagadougou',
    quartier: 'Tampouy',
    telephone: '+22625371122',
    horaires: '24h/24',
    distanceMeters: 4800,
    categorie: CategoryModel(id: 2, nom: 'Station-service', slug: 'station-service', icone: 'local_gas_station'),
  ),
  PlaceModel(
    id: 21,
    nom: 'Maquis Le Baobab',
    description: 'Restauration burkinabè, brochettes et terrasse',
    categorieId: 3,
    latitude: 12.3630,
    longitude: -1.5170,
    ville: 'Ouagadougou',
    quartier: 'Kwame N\'Krumah',
    telephone: '+22670224455',
    horaires: '11h - 01h',
    distanceMeters: 2200,
    categorie: CategoryModel(id: 3, nom: 'Maquis / Resto', slug: 'maquis-restaurant', icone: 'restaurant'),
  ),
  PlaceModel(
    id: 22,
    nom: 'Pharmacie de Kilwin',
    description: 'Pharmacie de garde 24h/24 au cœur de Kilwin / Tampouy Nord',
    categorieId: 1,
    latitude: 12.4172,
    longitude: -1.5645,
    ville: 'Ouagadougou',
    quartier: 'Kilwin',
    telephone: '+22625400011',
    horaires: '24h/24',
    distanceMeters: 120,
    tags: {'de_garde': true},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 23,
    nom: 'Total Échangeur du Nord',
    description: 'Station-service, carburant, gonflage et boutique 24h/24',
    categorieId: 2,
    latitude: 12.4105,
    longitude: -1.5585,
    ville: 'Ouagadougou',
    quartier: 'Tampouy',
    telephone: '+22625410022',
    horaires: '24h/24',
    distanceMeters: 850,
    categorie: CategoryModel(id: 2, nom: 'Station-service', slug: 'station-service', icone: 'local_gas_station'),
  ),
  PlaceModel(
    id: 24,
    nom: 'Shell Tampouy Kilwin',
    description: 'Station-service avec baie de vidange et lubrifiants',
    categorieId: 2,
    latitude: 12.4220,
    longitude: -1.5680,
    ville: 'Ouagadougou',
    quartier: 'Kilwin',
    telephone: '+22625420033',
    horaires: '24h/24',
    distanceMeters: 650,
    categorie: CategoryModel(id: 2, nom: 'Station-service', slug: 'station-service', icone: 'local_gas_station'),
  ),
  PlaceModel(
    id: 25,
    nom: 'Pharmacie Béthesda Tampouy',
    description: 'Officine de garde accessible sur l\'axe principal de Tampouy',
    categorieId: 1,
    latitude: 12.4045,
    longitude: -1.5560,
    ville: 'Ouagadougou',
    quartier: 'Tampouy',
    telephone: '+22625430044',
    horaires: '24h/24',
    distanceMeters: 1400,
    tags: {'de_garde': true},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 26,
    nom: 'CMA Paul VI (Hôpital Tampouy)',
    description: 'Centre Médical avec Urgences et Maternité',
    categorieId: 4,
    latitude: 12.3980,
    longitude: -1.5520,
    ville: 'Ouagadougou',
    quartier: 'Tampouy',
    telephone: '+22625370000',
    horaires: '24h/24',
    distanceMeters: 2100,
    categorie: CategoryModel(id: 4, nom: 'Hôpital / Urgences', slug: 'hopital-sante', icone: 'local_hospital'),
  ),
  PlaceModel(
    id: 27,
    nom: 'Maquis La Paillote Tampouy',
    description: 'Espace convivial, poulet grillé et boissons fraîches',
    categorieId: 3,
    latitude: 12.4120,
    longitude: -1.5620,
    ville: 'Ouagadougou',
    quartier: 'Tampouy',
    telephone: '+22670998877',
    horaires: '12h - 00h',
    distanceMeters: 550,
    categorie: CategoryModel(id: 3, nom: 'Maquis / Resto', slug: 'maquis-restaurant', icone: 'restaurant'),
  ),
  // --- Boutiques, Supermarchés, Alimentations & Marchés de Ouaga ---
  PlaceModel(
    id: 28,
    nom: 'Marina Market Koulouba',
    description: 'Grand supermarché, alimentation générale et produits frais',
    categorieId: 8,
    latitude: 12.3670,
    longitude: -1.5210,
    ville: 'Ouagadougou',
    quartier: 'Koulouba',
    horaires: '08h - 22h',
    categorie: CategoryModel(id: 8, nom: 'Marché / Boutique', slug: 'marche-commerce', icone: 'shopping_basket'),
  ),
  PlaceModel(
    id: 29,
    nom: 'Marina Market Ouaga 2000',
    description: 'Supermarché moderne, boulangerie et produits importés',
    categorieId: 8,
    latitude: 12.3230,
    longitude: -1.5110,
    ville: 'Ouagadougou',
    quartier: 'Ouaga 2000',
    horaires: '08h - 22h',
    categorie: CategoryModel(id: 8, nom: 'Marché / Boutique', slug: 'marche-commerce', icone: 'shopping_basket'),
  ),
  PlaceModel(
    id: 30,
    nom: 'Alimentation La Surface',
    description: 'Alimentation libre-service centrale, boissons et épicerie',
    categorieId: 8,
    latitude: 12.3645,
    longitude: -1.5165,
    ville: 'Ouagadougou',
    quartier: 'Kwame N\'Krumah',
    horaires: '07h30 - 23h',
    categorie: CategoryModel(id: 8, nom: 'Marché / Boutique', slug: 'marche-commerce', icone: 'storefront'),
  ),
  PlaceModel(
    id: 31,
    nom: 'Supermarché Scimas',
    description: 'Commerce de référence, alimentation et équipement',
    categorieId: 8,
    latitude: 12.3665,
    longitude: -1.5235,
    ville: 'Ouagadougou',
    quartier: 'Centre-Ville',
    horaires: '08h - 20h',
    categorie: CategoryModel(id: 8, nom: 'Marché / Boutique', slug: 'marche-commerce', icone: 'shopping_cart'),
  ),
  PlaceModel(
    id: 32,
    nom: 'Alimentation Le Bon Samaritain',
    description: 'Boutique d\'alimentation générale de quartier, dépôt de pain',
    categorieId: 8,
    latitude: 12.3890,
    longitude: -1.4980,
    ville: 'Ouagadougou',
    quartier: 'Somgandé',
    horaires: '07h - 23h',
    categorie: CategoryModel(id: 8, nom: 'Marché / Boutique', slug: 'marche-commerce', icone: 'storefront'),
  ),
  PlaceModel(
    id: 33,
    nom: 'Alimentation du Bon Berger',
    description: 'Épicerie, alimentation générale et produits du quotidien',
    categorieId: 8,
    latitude: 12.3490,
    longitude: -1.5590,
    ville: 'Ouagadougou',
    quartier: 'Pissy',
    horaires: '07h - 22h30',
    categorie: CategoryModel(id: 8, nom: 'Marché / Boutique', slug: 'marche-commerce', icone: 'storefront'),
  ),
  PlaceModel(
    id: 34,
    nom: 'Marché Sankaryare',
    description: 'Grand marché populaire de gros et détail de Paspanga',
    categorieId: 8,
    latitude: 12.3785,
    longitude: -1.5160,
    ville: 'Ouagadougou',
    quartier: 'Paspanga',
    horaires: '06h30 - 18h30',
    categorie: CategoryModel(id: 8, nom: 'Marché / Boutique', slug: 'marche-commerce', icone: 'storefront'),
  ),
  PlaceModel(
    id: 35,
    nom: 'Marché 10 Yaar',
    description: 'Marché animé des 1200 Logements et Wemtenga',
    categorieId: 8,
    latitude: 12.3640,
    longitude: -1.4990,
    ville: 'Ouagadougou',
    quartier: '1200 Logements',
    horaires: '07h - 19h',
    categorie: CategoryModel(id: 8, nom: 'Marché / Boutique', slug: 'marche-commerce', icone: 'storefront'),
  ),
  PlaceModel(
    id: 36,
    nom: 'Marché de Nabi Yaar',
    description: 'Marché de quartier vivant de Dassasgho',
    categorieId: 8,
    latitude: 12.3580,
    longitude: -1.4880,
    ville: 'Ouagadougou',
    quartier: 'Dassasgho',
    horaires: '07h - 19h',
    categorie: CategoryModel(id: 8, nom: 'Marché / Boutique', slug: 'marche-commerce', icone: 'storefront'),
  ),
  PlaceModel(
    id: 37,
    nom: 'Marché de Gounghin',
    description: 'Marché historique de vivres et artisanat de Gounghin',
    categorieId: 8,
    latitude: 12.3540,
    longitude: -1.5450,
    ville: 'Ouagadougou',
    quartier: 'Gounghin',
    horaires: '07h - 19h',
    categorie: CategoryModel(id: 8, nom: 'Marché / Boutique', slug: 'marche-commerce', icone: 'storefront'),
  ),
  PlaceModel(
    id: 38,
    nom: 'Marché de Tampouy',
    description: 'Pôle commercial majeur de l\'arrondissement de Sig-Noghin',
    categorieId: 8,
    latitude: 12.3950,
    longitude: -1.5480,
    ville: 'Ouagadougou',
    quartier: 'Tampouy',
    horaires: '07h - 19h',
    categorie: CategoryModel(id: 8, nom: 'Marché / Boutique', slug: 'marche-commerce', icone: 'storefront'),
  ),
  // --- Écoles, Lycées & Universités de Ouagadougou ---
  PlaceModel(
    id: 39,
    nom: 'Université Thomas Sankara',
    description: 'Grand campus universitaire de Saaba / Route de Fada',
    categorieId: 7,
    latitude: 12.3720,
    longitude: -1.4350,
    ville: 'Ouagadougou',
    quartier: 'Saaba',
    horaires: '07h30 - 19h',
    categorie: CategoryModel(id: 7, nom: 'École & Université', slug: 'ecole-universite', icone: 'school'),
  ),
  PlaceModel(
    id: 40,
    nom: 'Lycée Philippe Zinda Kaboré',
    description: 'Grand lycée public historique au cœur de Ouaga',
    categorieId: 7,
    latitude: 12.3660,
    longitude: -1.5260,
    ville: 'Ouagadougou',
    quartier: 'Centre-Ville',
    horaires: '07h - 17h',
    categorie: CategoryModel(id: 7, nom: 'École & Université', slug: 'ecole-universite', icone: 'school'),
  ),
  PlaceModel(
    id: 41,
    nom: 'Lycée de Bogodogo',
    description: 'Lycée départemental et pôle éducatif de l\'Est',
    categorieId: 7,
    latitude: 12.3620,
    longitude: -1.4910,
    ville: 'Ouagadougou',
    quartier: 'Dassasgho',
    horaires: '07h - 17h',
    categorie: CategoryModel(id: 7, nom: 'École & Université', slug: 'ecole-universite', icone: 'school'),
  ),
  PlaceModel(
    id: 42,
    nom: 'Lycée Nelson Mandela',
    description: 'Lycée d\'enseignement général et technique réputé',
    categorieId: 7,
    latitude: 12.3710,
    longitude: -1.5120,
    ville: 'Ouagadougou',
    quartier: 'Centre-Ville',
    horaires: '07h - 17h',
    categorie: CategoryModel(id: 7, nom: 'École & Université', slug: 'ecole-universite', icone: 'school'),
  ),
  PlaceModel(
    id: 43,
    nom: 'Lycée Marien N\'Gouabi',
    description: 'Établissement scolaire public de référence à Gounghin',
    categorieId: 7,
    latitude: 12.3600,
    longitude: -1.5390,
    ville: 'Ouagadougou',
    quartier: 'Gounghin',
    horaires: '07h - 17h',
    categorie: CategoryModel(id: 7, nom: 'École & Université', slug: 'ecole-universite', icone: 'school'),
  ),
  PlaceModel(
    id: 44,
    nom: 'Collège Saint Jean-Baptiste de La Salle',
    description: 'Collège et lycée d\'enseignement catholique réputé',
    categorieId: 7,
    latitude: 12.3640,
    longitude: -1.5200,
    ville: 'Ouagadougou',
    quartier: 'Koulouba',
    horaires: '07h - 17h30',
    categorie: CategoryModel(id: 7, nom: 'École & Université', slug: 'ecole-universite', icone: 'school'),
  ),
  PlaceModel(
    id: 45,
    nom: 'ENAM (École Nat. d\'Administration et de Magistrature)',
    description: 'Grande école de formation des cadres de l\'État',
    categorieId: 7,
    latitude: 12.3730,
    longitude: -1.5190,
    ville: 'Ouagadougou',
    quartier: 'Koulouba',
    horaires: '07h30 - 18h',
    categorie: CategoryModel(id: 7, nom: 'École & Université', slug: 'ecole-universite', icone: 'school'),
  ),
  PlaceModel(
    id: 46,
    nom: 'ISIG International',
    description: 'Institut supérieur d\'informatique et de gestion',
    categorieId: 7,
    latitude: 12.3670,
    longitude: -1.4960,
    ville: 'Ouagadougou',
    quartier: '1200 Logements',
    horaires: '08h - 19h',
    categorie: CategoryModel(id: 7, nom: 'École & Université', slug: 'ecole-universite', icone: 'school'),
  ),
  PlaceModel(
    id: 47,
    nom: 'Institut 2iE (Eau et Environnement)',
    description: 'Grande école d\'ingénieurs inter-États',
    categorieId: 7,
    latitude: 12.3680,
    longitude: -1.5140,
    ville: 'Ouagadougou',
    quartier: 'Koulouba',
    horaires: '08h - 18h',
    categorie: CategoryModel(id: 7, nom: 'École & Université', slug: 'ecole-universite', icone: 'school'),
  ),
  // --- Administrations & Bâtiments publics de Ouagadougou ---
  PlaceModel(
    id: 48,
    nom: 'Mairie Centrale de Ouagadougou',
    description: 'Hôtel de ville central et services municipaux',
    categorieId: 5,
    latitude: 12.3675,
    longitude: -1.5255,
    ville: 'Ouagadougou',
    quartier: 'Centre-Ville',
    horaires: '07h30 - 16h',
    categorie: CategoryModel(id: 5, nom: 'Administration', slug: 'administration', icone: 'account_balance'),
  ),
  PlaceModel(
    id: 49,
    nom: 'Mairie de Baskuy (Arrondissement 1)',
    description: 'Mairie d\'arrondissement, état civil et légalisations',
    categorieId: 5,
    latitude: 12.3725,
    longitude: -1.5240,
    ville: 'Ouagadougou',
    quartier: 'Baskuy',
    horaires: '07h30 - 16h',
    categorie: CategoryModel(id: 5, nom: 'Administration', slug: 'administration', icone: 'account_balance'),
  ),
  PlaceModel(
    id: 50,
    nom: 'Mairie de Bogodogo',
    description: 'Mairie d\'arrondissement du secteur Est',
    categorieId: 5,
    latitude: 12.3550,
    longitude: -1.4850,
    ville: 'Ouagadougou',
    quartier: 'Dassasgho',
    horaires: '07h30 - 16h',
    categorie: CategoryModel(id: 5, nom: 'Administration', slug: 'administration', icone: 'account_balance'),
  ),
  PlaceModel(
    id: 51,
    nom: 'Mairie de Boulmiougou',
    description: 'Mairie d\'arrondissement du secteur Ouest',
    categorieId: 5,
    latitude: 12.3470,
    longitude: -1.5520,
    ville: 'Ouagadougou',
    quartier: 'Pissy',
    horaires: '07h30 - 16h',
    categorie: CategoryModel(id: 5, nom: 'Administration', slug: 'administration', icone: 'account_balance'),
  ),
  PlaceModel(
    id: 52,
    nom: 'Mairie de Nongr-Maasom',
    description: 'Mairie d\'arrondissement du secteur Nord-Est',
    categorieId: 5,
    latitude: 12.3920,
    longitude: -1.5010,
    ville: 'Ouagadougou',
    quartier: 'Somgandé',
    horaires: '07h30 - 16h',
    categorie: CategoryModel(id: 5, nom: 'Administration', slug: 'administration', icone: 'account_balance'),
  ),
  PlaceModel(
    id: 53,
    nom: 'Mairie de Sig-Noghin',
    description: 'Mairie d\'arrondissement du secteur Nord',
    categorieId: 5,
    latitude: 12.4010,
    longitude: -1.5510,
    ville: 'Ouagadougou',
    quartier: 'Tampouy',
    horaires: '07h30 - 16h',
    categorie: CategoryModel(id: 5, nom: 'Administration', slug: 'administration', icone: 'account_balance'),
  ),
  PlaceModel(
    id: 54,
    nom: 'Primature du Burkina Faso',
    description: 'Siège du Premier Ministère et du Gouvernement',
    categorieId: 5,
    latitude: 12.3685,
    longitude: -1.5175,
    ville: 'Ouagadougou',
    quartier: 'Koulouba',
    horaires: '07h30 - 16h',
    categorie: CategoryModel(id: 5, nom: 'Administration', slug: 'administration', icone: 'account_balance'),
  ),
  PlaceModel(
    id: 55,
    nom: 'Commissariat Central de Police',
    description: 'Commissariat central de police de Ouagadougou',
    categorieId: 5,
    latitude: 12.3690,
    longitude: -1.5250,
    ville: 'Ouagadougou',
    quartier: 'Centre-Ville',
    telephone: '+22625306101',
    horaires: '24h/24',
    categorie: CategoryModel(id: 5, nom: 'Administration', slug: 'administration', icone: 'local_police'),
  ),
  PlaceModel(
    id: 56,
    nom: 'Palais de Justice de Ouagadougou',
    description: 'Tribunal de Grande Instance et Cours de justice',
    categorieId: 5,
    latitude: 12.3668,
    longitude: -1.5280,
    ville: 'Ouagadougou',
    quartier: 'Centre-Ville',
    horaires: '07h30 - 16h',
    categorie: CategoryModel(id: 5, nom: 'Administration', slug: 'administration', icone: 'gavel'),
  ),
  PlaceModel(
    id: 57,
    nom: 'RTB Télévision Nationale',
    description: 'Siège de la Radiodiffusion Télévision du Burkina',
    categorieId: 5,
    latitude: 12.3660,
    longitude: -1.5220,
    ville: 'Ouagadougou',
    quartier: 'Centre-Ville',
    horaires: '24h/24',
    categorie: CategoryModel(id: 5, nom: 'Administration', slug: 'administration', icone: 'tv'),
  ),
  // --- Pharmacies de jour et de quartier (non de garde) ---
  PlaceModel(
    id: 58,
    nom: 'Pharmacie Nouvelle',
    description: 'Pharmacie moderne sur l\'avenue Kwame N\'Krumah',
    categorieId: 1,
    latitude: 12.3654,
    longitude: -1.5173,
    ville: 'Ouagadougou',
    quartier: 'Koulouba',
    telephone: '+22625306641',
    horaires: '07h30 - 22h',
    tags: {'de_garde': false},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 59,
    nom: 'Pharmacie Wend-Kuuni',
    description: 'Pharmacie accessible près de l\'Université Ki-Zerbo',
    categorieId: 1,
    latitude: 12.3780,
    longitude: -1.4885,
    ville: 'Ouagadougou',
    quartier: 'Dassasgho',
    telephone: '+22625360022',
    horaires: '07h30 - 22h',
    tags: {'de_garde': false},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 60,
    nom: 'Pharmacie Hosanna',
    description: 'Officine pharmaceutique de la Patte d\'Oie',
    categorieId: 1,
    latitude: 12.3360,
    longitude: -1.5230,
    ville: 'Ouagadougou',
    quartier: 'Patte d\'Oie',
    telephone: '+22625371234',
    horaires: '07h30 - 21h30',
    tags: {'de_garde': false},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 61,
    nom: 'Pharmacie de Pissy',
    description: 'Pharmacie de proximité du quartier Pissy / Route de Bobo',
    categorieId: 1,
    latitude: 12.3480,
    longitude: -1.5580,
    ville: 'Ouagadougou',
    quartier: 'Pissy',
    telephone: '+22625430055',
    horaires: '07h30 - 22h',
    tags: {'de_garde': false},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 62,
    nom: 'Pharmacie Kamboinsin',
    description: 'Officine sur la RN2 route de Ouahigouya',
    categorieId: 1,
    latitude: 12.4480,
    longitude: -1.5530,
    ville: 'Ouagadougou',
    quartier: 'Kamboinsin',
    telephone: '+22625410066',
    horaires: '07h30 - 21h30',
    tags: {'de_garde': false},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 63,
    nom: 'Pharmacie Liptako',
    description: 'Pharmacie de quartier de Karpala',
    categorieId: 1,
    latitude: 12.3270,
    longitude: -1.4720,
    ville: 'Ouagadougou',
    quartier: 'Karpala',
    telephone: '+22625380077',
    horaires: '07h30 - 22h',
    tags: {'de_garde': false},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 64,
    nom: 'Pharmacie Espoir Saaba',
    description: 'Pharmacie accessible de la commune de Saaba',
    categorieId: 1,
    latitude: 12.3680,
    longitude: -1.4420,
    ville: 'Ouagadougou',
    quartier: 'Saaba',
    telephone: '+22625490088',
    horaires: '07h30 - 22h',
    tags: {'de_garde': false},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 65,
    nom: 'Pharmacie Dag-Noen',
    description: 'Officine de quartier du secteur Dag-Noen',
    categorieId: 1,
    latitude: 12.3730,
    longitude: -1.4780,
    ville: 'Ouagadougou',
    quartier: 'Dag-Noen',
    telephone: '+22625361199',
    horaires: '07h30 - 21h30',
    tags: {'de_garde': false},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  PlaceModel(
    id: 66,
    nom: 'Pharmacie Saint-François Tanghin',
    description: 'Pharmacie de proximité du quartier Tanghin',
    categorieId: 1,
    latitude: 12.3910,
    longitude: -1.5170,
    ville: 'Ouagadougou',
    quartier: 'Tanghin',
    telephone: '+22625352200',
    horaires: '07h30 - 22h',
    tags: {'de_garde': false},
    categorie: CategoryModel(id: 1, nom: 'Pharmacie', slug: 'pharmacie', icone: 'local_pharmacy'),
  ),
  // --- Hôpitaux, Cliniques & CSPS ---
  PlaceModel(
    id: 67,
    nom: 'CHU de Bogodogo',
    description: 'Nouveau Centre Hospitalier Universitaire et Urgences',
    categorieId: 4,
    latitude: 12.3482,
    longitude: -1.4721,
    ville: 'Ouagadougou',
    quartier: 'Bogodogo',
    telephone: '+22625370000',
    horaires: '24h/24',
    categorie: CategoryModel(id: 4, nom: 'Hôpital / Urgences', slug: 'hopital-sante', icone: 'local_hospital'),
  ),
  PlaceModel(
    id: 68,
    nom: 'CHU de Tengandogo (Hôpital Blaise Compaoré)',
    description: 'Hôpital moderne de référence internationale',
    categorieId: 4,
    latitude: 12.2880,
    longitude: -1.5280,
    ville: 'Ouagadougou',
    quartier: 'Tengandogo',
    telephone: '+22625378888',
    horaires: '24h/24',
    categorie: CategoryModel(id: 4, nom: 'Hôpital / Urgences', slug: 'hopital-sante', icone: 'local_hospital'),
  ),
  PlaceModel(
    id: 69,
    nom: 'CMA de Pissy',
    description: 'Centre Médical avec antenne chirurgicale et maternité',
    categorieId: 4,
    latitude: 12.3460,
    longitude: -1.5540,
    ville: 'Ouagadougou',
    quartier: 'Pissy',
    telephone: '+22625431100',
    horaires: '24h/24',
    categorie: CategoryModel(id: 4, nom: 'Hôpital / Urgences', slug: 'hopital-sante', icone: 'local_hospital'),
  ),
  PlaceModel(
    id: 70,
    nom: 'CSPS de Gounghin',
    description: 'Centre de Santé et de Promotion Sociale',
    categorieId: 4,
    latitude: 12.3560,
    longitude: -1.5430,
    ville: 'Ouagadougou',
    quartier: 'Gounghin',
    horaires: '24h/24',
    categorie: CategoryModel(id: 4, nom: 'Hôpital / Urgences', slug: 'hopital-sante', icone: 'local_hospital'),
  ),
  PlaceModel(
    id: 71,
    nom: 'CSPS de Wemtenga',
    description: 'Centre de Santé et de Promotion Sociale de Wemtenga',
    categorieId: 4,
    latitude: 12.3520,
    longitude: -1.4950,
    ville: 'Ouagadougou',
    quartier: 'Wemtenga',
    horaires: '24h/24',
    categorie: CategoryModel(id: 4, nom: 'Hôpital / Urgences', slug: 'hopital-sante', icone: 'local_hospital'),
  ),
  PlaceModel(
    id: 72,
    nom: 'Clinique Notre-Dame de la Paix',
    description: 'Clinique médico-chirurgicale privée',
    categorieId: 4,
    latitude: 12.3690,
    longitude: -1.5160,
    ville: 'Ouagadougou',
    quartier: 'Koulouba',
    telephone: '+22625312345',
    horaires: '24h/24',
    categorie: CategoryModel(id: 4, nom: 'Hôpital / Urgences', slug: 'hopital-sante', icone: 'local_hospital'),
  ),
  // --- Stations-service supplémentaires ---
  PlaceModel(
    id: 73,
    nom: 'Total Gounghin',
    description: 'Station-service, lubrifiants et gonflage deux-roues 24h/24',
    categorieId: 2,
    latitude: 12.3590,
    longitude: -1.5440,
    ville: 'Ouagadougou',
    quartier: 'Gounghin',
    horaires: '24h/24',
    categorie: CategoryModel(id: 2, nom: 'Station-service', slug: 'station-service', icone: 'local_gas_station'),
  ),
  PlaceModel(
    id: 74,
    nom: 'Total Ouaga 2000',
    description: 'Station-service moderne et boutique Bonjour',
    categorieId: 2,
    latitude: 12.3240,
    longitude: -1.5090,
    ville: 'Ouagadougou',
    quartier: 'Ouaga 2000',
    horaires: '24h/24',
    categorie: CategoryModel(id: 2, nom: 'Station-service', slug: 'station-service', icone: 'local_gas_station'),
  ),
  PlaceModel(
    id: 75,
    nom: 'Petrofa Zogona',
    description: 'Carburant et gonflage pneus deux-roues',
    categorieId: 2,
    latitude: 12.3740,
    longitude: -1.4990,
    ville: 'Ouagadougou',
    quartier: 'Zogona',
    horaires: '24h/24',
    categorie: CategoryModel(id: 2, nom: 'Station-service', slug: 'station-service', icone: 'local_gas_station'),
  ),
  PlaceModel(
    id: 76,
    nom: 'Oryx Somgandé',
    description: 'Station-service Oryx avec boutique de nuit',
    categorieId: 2,
    latitude: 12.3870,
    longitude: -1.5040,
    ville: 'Ouagadougou',
    quartier: 'Somgandé',
    horaires: '24h/24',
    categorie: CategoryModel(id: 2, nom: 'Station-service', slug: 'station-service', icone: 'local_gas_station'),
  ),
  // --- Maquis & Restaurants de référence ---
  PlaceModel(
    id: 77,
    nom: 'Maquis Le Verdoyant',
    description: 'Restaurant terrasse réputé près de la Place de la Nation',
    categorieId: 3,
    latitude: 12.3659,
    longitude: -1.5245,
    ville: 'Ouagadougou',
    quartier: 'Koulouba',
    horaires: '11h - 00h',
    categorie: CategoryModel(id: 3, nom: 'Maquis / Resto', slug: 'maquis-restaurant', icone: 'restaurant'),
  ),
  PlaceModel(
    id: 78,
    nom: 'Maquis Les Étoiles de Ouaga 2000',
    description: 'Poulet bicyclette braisé et boissons fraîches en terrasse',
    categorieId: 3,
    latitude: 12.3250,
    longitude: -1.5085,
    ville: 'Ouagadougou',
    quartier: 'Ouaga 2000',
    horaires: '12h - 02h',
    categorie: CategoryModel(id: 3, nom: 'Maquis / Resto', slug: 'maquis-restaurant', icone: 'restaurant'),
  ),
  PlaceModel(
    id: 79,
    nom: 'Restaurant Gondwana',
    description: 'Spécialités africaines et grillades au feu de bois',
    categorieId: 3,
    latitude: 12.3640,
    longitude: -1.5215,
    ville: 'Ouagadougou',
    quartier: 'Centre-Ville',
    horaires: '11h - 23h',
    categorie: CategoryModel(id: 3, nom: 'Maquis / Resto', slug: 'maquis-restaurant', icone: 'restaurant'),
  ),
  PlaceModel(
    id: 80,
    nom: 'Maquis Le Poulet Chaud Pissy',
    description: 'Poulet braisé local et rafraîchissements',
    categorieId: 3,
    latitude: 12.3475,
    longitude: -1.5560,
    ville: 'Ouagadougou',
    quartier: 'Pissy',
    horaires: '12h - 01h',
    categorie: CategoryModel(id: 3, nom: 'Maquis / Resto', slug: 'maquis-restaurant', icone: 'restaurant'),
  ),
  // --- Banques, GAB & Distributeurs ---
  PlaceModel(
    id: 81,
    nom: 'Coris Bank Siège',
    description: 'Siège social Coris Bank International et guichet GAB 24h/24',
    categorieId: 6,
    latitude: 12.3670,
    longitude: -1.5240,
    ville: 'Ouagadougou',
    quartier: 'Centre-Ville',
    horaires: '08h - 16h (GAB 24h/24)',
    categorie: CategoryModel(id: 6, nom: 'Banque & DAB', slug: 'banque-distributeur', icone: 'account_balance'),
  ),
  PlaceModel(
    id: 82,
    nom: 'BOA Burkina Siège',
    description: 'Siège Bank of Africa et distributeurs automatiques GAB',
    categorieId: 6,
    latitude: 12.3650,
    longitude: -1.5180,
    ville: 'Ouagadougou',
    quartier: 'Kwame N\'Krumah',
    horaires: '08h - 16h (GAB 24h/24)',
    categorie: CategoryModel(id: 6, nom: 'Banque & DAB', slug: 'banque-distributeur', icone: 'account_balance'),
  ),
  PlaceModel(
    id: 83,
    nom: 'Ecobank Burkina Siège',
    description: 'Siège Ecobank et espace bancaire libre-service GAB',
    categorieId: 6,
    latitude: 12.3685,
    longitude: -1.5210,
    ville: 'Ouagadougou',
    quartier: 'Centre-Ville',
    horaires: '08h - 16h (GAB 24h/24)',
    categorie: CategoryModel(id: 6, nom: 'Banque & DAB', slug: 'banque-distributeur', icone: 'account_balance'),
  ),
  PlaceModel(
    id: 84,
    nom: 'GAB Coris Bank 1200 Logements',
    description: 'Distributeur automatique de billets accessible 24h/24',
    categorieId: 6,
    latitude: 12.3680,
    longitude: -1.4980,
    ville: 'Ouagadougou',
    quartier: '1200 Logements',
    horaires: '24h/24',
    categorie: CategoryModel(id: 6, nom: 'Banque & DAB', slug: 'banque-distributeur', icone: 'credit_card'),
  ),
  PlaceModel(
    id: 85,
    nom: 'GAB Ecobank Tampouy',
    description: 'Distributeur automatique GAB et agence de Tampouy',
    categorieId: 6,
    latitude: 12.3940,
    longitude: -1.5490,
    ville: 'Ouagadougou',
    quartier: 'Tampouy',
    horaires: '24h/24',
    categorie: CategoryModel(id: 6, nom: 'Banque & DAB', slug: 'banque-distributeur', icone: 'credit_card'),
  ),
  PlaceModel(
    id: 991,
    nom: 'Pont Kadiogo',
    nameTts: 'Pont Kadjogo',
    description: 'Pont principal franchissant le canal Kadiogo',
    categorieId: 5,
    latitude: 12.3730,
    longitude: -1.5120,
    ville: 'Ouagadougou',
    isAnchor: true,
    importance: 4,
    confidence: 3,
    categorie: CategoryModel(id: 5, nom: 'Infrastructure', slug: 'pont', icone: 'alt_route'),
  ),
  PlaceModel(
    id: 992,
    nom: 'Échangeur du Nord',
    nameTts: 'Échangeur du Nord',
    description: 'Grand échangeur moderne sortie Nord de Ouaga',
    categorieId: 5,
    latitude: 12.3950,
    longitude: -1.5350,
    ville: 'Ouagadougou',
    isAnchor: true,
    importance: 5,
    confidence: 3,
    categorie: CategoryModel(id: 5, nom: 'Infrastructure', slug: 'echangeur', icone: 'alt_route'),
  ),
  PlaceModel(
    id: 993,
    nom: 'Échangeur de l\'Est',
    nameTts: 'Échangeur de l\'Est',
    description: 'Échangeur RN4 surplombant la voie ferrée',
    categorieId: 5,
    latitude: 12.3615,
    longitude: -1.4855,
    ville: 'Ouagadougou',
    isAnchor: true,
    importance: 5,
    confidence: 3,
    categorie: CategoryModel(id: 5, nom: 'Infrastructure', slug: 'echangeur', icone: 'alt_route'),
  ),
  PlaceModel(
    id: 994,
    nom: 'Feu croisement 1200 Logements',
    nameTts: 'Feu du 1200 Logements',
    description: 'Carrefour à feux tricolores régulés',
    categorieId: 5,
    latitude: 12.3689,
    longitude: -1.4985,
    ville: 'Ouagadougou',
    isAnchor: true,
    importance: 4,
    confidence: 3,
    categorie: CategoryModel(id: 5, nom: 'Signalisation', slug: 'feu', icone: 'traffic'),
  ),
  PlaceModel(
    id: 995,
    nom: 'Rond-Point des Nations Unies',
    nameTts: 'Rond-Point des Nations Unies',
    description: 'Grand rond-point central de Ouagadougou',
    categorieId: 5,
    latitude: 12.3700,
    longitude: -1.5180,
    ville: 'Ouagadougou',
    isAnchor: true,
    importance: 5,
    confidence: 3,
    categorie: CategoryModel(id: 5, nom: 'Rond-point', slug: 'rond-point', icone: 'change_circle'),
  ),
];

/// Filtre spécifique pharmacies de garde (activable via UI, faux par défaut pour afficher toutes les pharmacies)
class OnlyDeGardeNotifier extends Notifier<bool> {
  @override
  bool build() => false;
  void toggle() => state = !state;
  void setVal(bool value) => state = value;
}

final onlyDeGardeFilterProvider = NotifierProvider<OnlyDeGardeNotifier, bool>(
  OnlyDeGardeNotifier.new,
);

/// Fournisseur des lieux à proximité (autour de l'utilisateur ou du centre sélectionné)
final nearbyPlacesProvider = FutureProvider<List<PlaceModel>>((ref) async {
  final repository = ref.watch(placesRepositoryProvider);
  final location = ref.watch(currentLocationProvider);
  final selectedCats = ref.watch(selectedCategoriesProvider);
  final onlyDeGarde = ref.watch(onlyDeGardeFilterProvider);

  bool matchesCategory(PlaceModel place) {
    final slug = (place.categorie?.slug ?? '').toLowerCase();
    final nom = place.nom.toLowerCase();
    final isPharmacie = slug.contains('pharmacie') || nom.contains('pharmacie');

    if (onlyDeGarde && isPharmacie && !place.isDeGarde) {
      return false;
    }

    if (selectedCats.isEmpty) return true;

    for (final cat in selectedCats) {
      final c = cat.toLowerCase();
      if (slug == c || slug.contains(c) || nom.contains(c)) return true;
      if (c == 'pharmacie' && isPharmacie) return true;
      if ((c == 'station' || c == 'station-service') &&
          (slug.contains('station') || nom.contains('station') || nom.contains('total') || nom.contains('shell') || nom.contains('oryx') || nom.contains('petrofa'))) {
        return true;
      }
      if ((c == 'hopital' || c == 'hopital-sante') &&
          (slug.contains('hopital') || nom.contains('hopital') || nom.contains('chu') || nom.contains('cma') || nom.contains('csps') || nom.contains('clinique'))) {
        return true;
      }
      if ((c == 'maquis' || c == 'maquis-restaurant') &&
          (slug.contains('maquis') || slug.contains('resto') || nom.contains('maquis') || nom.contains('restaurant'))) {
        return true;
      }
      if ((c == 'administration' || c == 'admin') &&
          (slug.contains('admin') || slug.contains('patrimoine') || nom.contains('mairie') || nom.contains('commissariat') || nom.contains('ministere') || nom.contains('primature') || nom.contains('palais') || nom.contains('monument'))) {
        return true;
      }
      if ((c == 'ecole' || c == 'ecole-universite') &&
          (slug.contains('ecole') || nom.contains('universite') || nom.contains('lycee') || nom.contains('college') || nom.contains('enam') || nom.contains('isig') || nom.contains('2ie'))) {
        return true;
      }
      if ((c == 'marche' || c == 'marche-commerce') &&
          (slug.contains('marche') || slug.contains('commerce') || nom.contains('marche') || nom.contains('alimentation') || nom.contains('marina') || nom.contains('supermarche') || nom.contains('surface') || nom.contains('boutique'))) {
        return true;
      }
      if ((c == 'banque' || c == 'banque-distributeur') &&
          (slug.contains('banque') || nom.contains('banque') || nom.contains('coris') || nom.contains('boa') || nom.contains('ecobank') || nom.contains('gab'))) {
        return true;
      }
    }
    return false;
  }

  try {
    final searchRadius = selectedCats.isNotEmpty ? 15000.0 : 25000.0;
    final backendPlaces = await repository.getNearbyPlaces(
      lat: location.lat,
      lon: location.lon,
      radius: searchRadius,
      slug: selectedCats.isNotEmpty ? selectedCats.first : null,
      limit: 60,
    );

    // Initialiser avec tous les repères locaux et fusionner avec le serveur
    final Map<String, PlaceModel> placesMap = {};
    for (final p in defaultOuagaIconicPlaces) {
      if (matchesCategory(p)) {
        placesMap[p.nom.toLowerCase().trim()] = p;
      }
    }
    for (final p in backendPlaces) {
      if (matchesCategory(p)) {
        placesMap[p.nom.toLowerCase().trim()] = p;
      }
    }

    final result = placesMap.values.toList();
    result.sort((a, b) {
      final distA = a.distanceTo(location.lat, location.lon);
      final distB = b.distanceTo(location.lat, location.lon);
      return distA.compareTo(distB);
    });
    return result;
  } catch (e) {
    AppLogger.w('Échec chargement lieux backend: $e');
    final localFiltered = defaultOuagaIconicPlaces.where(matchesCategory).toList();
    localFiltered.sort((a, b) => a.distanceTo(location.lat, location.lon).compareTo(b.distanceTo(location.lat, location.lon)));
    return localFiltered;
  }
});


/// Gestionnaire du lieu sélectionné (affiché dans la PoiPreviewCard)
class SelectedPlaceNotifier extends Notifier<PlaceModel?> {
  @override
  PlaceModel? build() => null;

  void select(PlaceModel? place) => state = place;
  void clear() => state = null;
}

final selectedPlaceProvider =
    NotifierProvider<SelectedPlaceNotifier, PlaceModel?>(
  SelectedPlaceNotifier.new,
);

/// Requête de recherche textuelle
class SearchQueryNotifier extends Notifier<String> {
  @override
  String build() => '';

  void setQuery(String query) => state = query;
  void clear() => state = '';
}

final searchQueryProvider =
    NotifierProvider<SearchQueryNotifier, String>(SearchQueryNotifier.new);

/// Résultats de recherche en direct connectés au backend et cache hors-ligne
final searchResultsProvider = FutureProvider<List<PlaceModel>>((ref) async {
  final query = ref.watch(searchQueryProvider);
  if (query.trim().isEmpty) {
    return [];
  }
  final repository = ref.watch(placesRepositoryProvider);
  final location = ref.watch(currentLocationProvider);
  return repository.searchPlaces(
    query: query.trim(),
    currentLat: location.lat,
    currentLon: location.lon,
    limit: 25,
  );
});

/// Indicateur d'affichage de la superposition de recherche
class SearchActiveNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void openSearch() => state = true;
  void closeSearch() => state = false;
  void toggle() => state = !state;
}

final searchActiveProvider =
    NotifierProvider<SearchActiveNotifier, bool>(SearchActiveNotifier.new);

/// Provider pour charger la fiche détaillée d'un lieu par son identifiant
final placeDetailProvider = FutureProvider.family<PlaceModel, String>((ref, placeId) async {
  final repository = ref.watch(placesRepositoryProvider);
  return repository.getPlaceDetail(placeId);
});
