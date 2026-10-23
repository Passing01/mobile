import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';

void main() {
  group('PlaceModel Tests', () {
    test('fromJson désérialise un POI complet avec catégorie imbriquée', () {
      final json = {
        'id': 10,
        'nom': 'Grand Marché Rood-Woko',
        'description': 'Marché central',
        'categorie_id': 3,
        'latitude': 12.3685,
        'longitude': -1.5222,
        'ville': 'Ouagadougou',
        'quartier': 'Centre-Ville',
        'telephone': '+22625300000',
        'horaires': '07h - 18h',
        'est_valide': true,
        'distance_meters': 532.2,
        'is_favorite': true,
        'categorie': {
          'id': 3,
          'nom': 'Maquis / Restaurant',
          'slug': 'maquis-restaurant',
          'icone': 'restaurant',
        },
      };

      final place = PlaceModel.fromJson(json);

      expect(place.id, 10);
      expect(place.nom, 'Grand Marché Rood-Woko');
      expect(place.categorieId, 3);
      expect(place.latitude, 12.3685);
      expect(place.longitude, -1.5222);
      expect(place.quartier, 'Centre-Ville');
      expect(place.distanceMeters, 532.2);
      expect(place.isFavorite, true);
      expect(place.categorie?.nom, 'Maquis / Restaurant');
      expect(place.formattedDistance, '532 m');
      expect(place.subtitle, 'Centre-Ville');
    });

    test('formattedDistance formate correctement en mètres ou kilomètres', () {
      const p1 = PlaceModel(
        id: 1,
        nom: 'P1',
        categorieId: 1,
        latitude: 12.0,
        longitude: -1.0,
        distanceMeters: 450.0,
      );
      expect(p1.formattedDistance, '450 m');

      const p2 = PlaceModel(
        id: 2,
        nom: 'P2',
        categorieId: 1,
        latitude: 12.0,
        longitude: -1.0,
        distanceMeters: 3450.0,
      );
      expect(p2.formattedDistance, '3.5 km');

      const p3 = PlaceModel(
        id: 3,
        nom: 'P3',
        categorieId: 1,
        latitude: 12.0,
        longitude: -1.0,
      );
      expect(p3.formattedDistance, isNull);
    });

    test('subtitle retourne quartier ou adresse ou ville selon priorité', () {
      const withQuartier = PlaceModel(
        id: 1,
        nom: 'P1',
        categorieId: 1,
        latitude: 12.0,
        longitude: -1.0,
        quartier: '1200 Logements',
        adresse: 'Avenue Babanguida',
      );
      expect(withQuartier.subtitle, '1200 Logements');

      const withAdresseOnly = PlaceModel(
        id: 2,
        nom: 'P2',
        categorieId: 1,
        latitude: 12.0,
        longitude: -1.0,
        adresse: 'Avenue Babanguida',
      );
      expect(withAdresseOnly.subtitle, 'Avenue Babanguida');

      const withVilleOnly = PlaceModel(
        id: 3,
        nom: 'P3',
        categorieId: 1,
        latitude: 12.0,
        longitude: -1.0,
        ville: 'Bobo-Dioulasso',
      );
      expect(withVilleOnly.subtitle, 'Bobo-Dioulasso');
    });
  });
}
