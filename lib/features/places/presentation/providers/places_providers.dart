import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qvgestion_mobile/core/config/app_constants.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
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
class SelectedCategoriesNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() => {};

  void toggleCategory(String slug) {
    final next = Set<String>.from(state);
    if (next.contains(slug)) {
      next.remove(slug);
    } else {
      next.add(slug);
    }
    state = next;
    ref.read(selectedCategorySlugProvider.notifier).syncFromCategories(next);
  }

  void selectCategory(String? slug) {
    if (slug == null) {
      clear();
    } else {
      toggleCategory(slug);
    }
  }

  void selectOnly(String slug) {
    if (state.length == 1 && state.contains(slug)) {
      clear();
    } else {
      state = {slug};
      ref.read(selectedCategorySlugProvider.notifier).syncFromCategories(state);
    }
  }

  void clear() {
    state = {};
    ref.read(selectedCategorySlugProvider.notifier).syncFromCategories(state);
  }
}

final selectedCategoriesProvider =
    NotifierProvider<SelectedCategoriesNotifier, Set<String>>(
  SelectedCategoriesNotifier.new,
);

/// Gestionnaire de la catégorie sélectionnée (slug) pour compatibilité ascendante
class SelectedCategoryNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void syncFromCategories(Set<String> categories) {
    state = categories.isNotEmpty ? categories.last : null;
  }

  void selectCategory(String? slug) {
    if (state == slug) {
      state = null;
      ref.read(selectedCategoriesProvider.notifier).clear();
    } else {
      state = slug;
      if (slug != null) {
        ref.read(selectedCategoriesProvider.notifier).selectOnly(slug);
      } else {
        ref.read(selectedCategoriesProvider.notifier).clear();
      }
    }
  }

  void clear() {
    state = null;
    ref.read(selectedCategoriesProvider.notifier).clear();
  }
}

final selectedCategorySlugProvider =
    NotifierProvider<SelectedCategoryNotifier, String?>(
  SelectedCategoryNotifier.new,
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

/// Provider GeoJSON des lieux de la zone visible selon les catégories cochées
final placesGeoJsonProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final selectedCats = ref.watch(selectedCategoriesProvider);
  if (selectedCats.isEmpty) {
    return {'type': 'FeatureCollection', 'features': []};
  }
  final repo = ref.watch(placesRepositoryProvider);
  final bbox = ref.watch(mapBoundingBoxProvider);
  final loc = ref.watch(currentLocationProvider);

  return repo.getPlacesGeoJson(
    categories: selectedCats.toList(),
    bbox: bbox,
    lat: loc.lat,
    lng: loc.lon,
  );
});

/// Compteur dynamique de lieux chargés
final placesCountProvider = Provider<int>((ref) {
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
  @override
  LocationState build() {
    return const LocationState(
      lat: AppConstants.ouagaCenterLatitude,
      lon: AppConstants.ouagaCenterLongitude,
      label: 'Ouagadougou, 1200 Logements',
    );
  }

  void updateLocation(double lat, double lon, [String? label]) {
    state = LocationState(
      lat: lat,
      lon: lon,
      label: label ?? 'Position actuelle',
    );
  }

  StreamSubscription<Position>? _positionStreamSub;

  /// Récupère la position GPS réelle du smartphone de l'utilisateur
  Future<void> fetchRealDeviceLocation() async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        AppLogger.w('Service de localisation désactivé sur l\'appareil');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          AppLogger.w('Permission de localisation refusée par l\'utilisateur');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        AppLogger.w('Permission de localisation refusée définitivement');
        return;
      }

      // 1. Position instantanée depuis le cache récent (< 50ms)
      final lastKnown = await Geolocator.getLastKnownPosition();
      if (lastKnown != null) {
        state = LocationState(
          lat: lastKnown.latitude,
          lon: lastKnown.longitude,
          label: 'Ma position GPS',
        );
        AppLogger.i('Position GPS obtenue immédiatement (cache natif): ${lastKnown.latitude}, ${lastKnown.longitude}');
      }

      // 2. Écoute du flux continu haute précision direct
      _positionStreamSub?.cancel();
      _positionStreamSub = Geolocator.getPositionStream(
        locationSettings: AndroidSettings(
          accuracy: LocationAccuracy.best,
          distanceFilter: 3,
          forceLocationManager: true,
          intervalDuration: const Duration(seconds: 2),
        ),
      ).listen((pos) {
        state = LocationState(
          lat: pos.latitude,
          lon: pos.longitude,
          label: 'Position GPS précise',
        );
      });

      // 3. Demande de position GPS précise directe (matériel GPS)
      try {
        final position = await Geolocator.getCurrentPosition(
          locationSettings: AndroidSettings(
            accuracy: LocationAccuracy.best,
            timeLimit: const Duration(seconds: 15),
            forceLocationManager: true,
          ),
        );

        state = LocationState(
          lat: position.latitude,
          lon: position.longitude,
          label: 'Position GPS précise',
        );
      } catch (e) {
        try {
          final position = await Geolocator.getCurrentPosition(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              timeLimit: Duration(seconds: 10),
            ),
          );
          state = LocationState(
            lat: position.latitude,
            lon: position.longitude,
            label: 'Position GPS réelle',
          );
        } catch (_) {
          if (lastKnown != null) {
            AppLogger.i('Maintien de la dernière position valide.');
          }
        }
      }
    } catch (e) {
      if (e.toString().contains('MissingPluginException') ||
          e.toString().contains('No implementation found')) {
        AppLogger.i(
          'ℹ️ Service GPS natif en attente. Position Ouaga active.',
        );
      } else {
        AppLogger.w('Erreur géolocalisation: $e');
      }
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
    categorieId: 3,
    latitude: 12.3685,
    longitude: -1.5222,
    ville: 'Ouagadougou',
    quartier: 'Centre-Ville',
    horaires: '07h - 18h',
    distanceMeters: 2540,
    categorie: CategoryModel(id: 3, nom: 'Marché / Commerce', slug: 'maquis-restaurant', icone: 'storefront'),
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
    categorie: CategoryModel(id: 5, nom: 'Site Culturel', slug: 'patrimoine', icone: 'account_balance'),
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
    categorie: CategoryModel(id: 5, nom: 'Place Publique', slug: 'patrimoine', icone: 'flag'),
  ),
  PlaceModel(
    id: 8,
    nom: 'Université Joseph Ki-Zerbo',
    description: 'Campus principal universitaire de Zogona',
    categorieId: 5,
    latitude: 12.3760,
    longitude: -1.5010,
    ville: 'Ouagadougou',
    quartier: 'Zogona',
    horaires: '07h - 20h',
    distanceMeters: 850,
    categorie: CategoryModel(id: 5, nom: 'Éducation', slug: 'patrimoine', icone: 'school'),
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
    categorie: CategoryModel(id: 5, nom: 'Exposition', slug: 'patrimoine', icone: 'palette'),
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
    categorie: CategoryModel(id: 5, nom: 'Mémorial', slug: 'patrimoine', icone: 'museum'),
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
];

/// Fournisseur des lieux à proximité (autour de l'utilisateur ou du centre sélectionné)
final nearbyPlacesProvider = FutureProvider<List<PlaceModel>>((ref) async {
  final repository = ref.watch(placesRepositoryProvider);
  final location = ref.watch(currentLocationProvider);
  final selectedCats = ref.watch(selectedCategoriesProvider);
  final selectedSlug = ref.watch(selectedCategorySlugProvider);

  bool matchesCategory(PlaceModel place) {
    if (selectedCats.isEmpty && selectedSlug == null) return true;
    final slug = (place.categorie?.slug ?? '').toLowerCase();
    final nom = place.nom.toLowerCase();

    for (final cat in selectedCats) {
      final c = cat.toLowerCase();
      if (slug == c || slug.contains(c)) {
        return true;
      }
      if (c == 'pharmacie' && (slug.contains('pharmacie') || nom.contains('pharmacie'))) {
        return true;
      }
      if ((c == 'station-service' || c == 'station') &&
          (slug.contains('station') || nom.contains('station') || nom.contains('total') || nom.contains('shell') || nom.contains('oil'))) {
        return true;
      }
      if ((c == 'maquis-restaurant' || c == 'maquis') &&
          (slug.contains('maquis') || slug.contains('restaurant') || nom.contains('maquis') || nom.contains('restaurant'))) {
        return true;
      }
      if ((c == 'hopital' || c == 'sante') &&
          (slug.contains('hopital') || nom.contains('chuy') || nom.contains('yalgado') || nom.contains('clinique') || nom.contains('cma'))) {
        return true;
      }
      if (c == 'administration' &&
          (slug.contains('admin') || nom.contains('mairie') || nom.contains('commissariat') || nom.contains('minist'))) {
        return true;
      }
    }

    if (selectedSlug != null) {
      final s = selectedSlug.toLowerCase();
      if (slug == s || slug.contains(s)) {
        return true;
      }
      if (s == 'pharmacie' && (slug.contains('pharmacie') || nom.contains('pharmacie'))) {
        return true;
      }
      if ((s == 'station-service' || s == 'station') &&
          (slug.contains('station') || nom.contains('station') || nom.contains('total') || nom.contains('shell'))) {
        return true;
      }
    }

    return false;
  }

  try {
    final searchRadius = (selectedCats.isNotEmpty || selectedSlug != null) ? 15000.0 : 25000.0;
    final backendPlaces = await repository.getNearbyPlaces(
      lat: location.lat,
      lon: location.lon,
      radius: searchRadius,
      slug: selectedSlug ?? (selectedCats.isNotEmpty ? selectedCats.first : null),
      limit: 60,
    );

    // Fusionner et filtrer rigoureusement selon les catégories sélectionnées
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

    return placesMap.values.toList();
  } catch (e) {
    AppLogger.w('Utilisation du catalogue de repères locaux de secours: $e');
    return defaultOuagaIconicPlaces.where(matchesCategory).toList();
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
