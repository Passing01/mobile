import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/places/data/models/search_models.dart';

void main() {
  group('Search Models Tests (Étape 11)', () {
    test('SearchAliasModel désérialisation JSON', () {
      final json = {
        'alias': 'santé',
        'label': 'Santé & Urgences',
        'icon': 'local_hospital',
        'color': '#DC2626',
        'category_ids': [4, 1],
        'category_slugs': ['hopital-sante', 'pharmacie'],
      };

      final model = SearchAliasModel.fromJson(json);
      expect(model.alias, equals('santé'));
      expect(model.label, equals('Santé & Urgences'));
      expect(model.categoryIds, equals([4, 1]));
      expect(model.categorySlugs, equals(['hopital-sante', 'pharmacie']));
      expect(model.iconData, equals(Icons.local_hospital_rounded));
      expect(model.colorValue, equals(const Color(0xFFDC2626)));
    });

    test('SearchResultModel désérialisation JSON avec résultats', () {
      final json = {
        'results': [
          {
            'id': 10,
            'nom': 'Pharmacie Yako',
            'latitude': 12.3714,
            'longitude': -1.5197,
            'categorie_id': 1,
            'categorie_slug': 'pharmacie',
            'importance': 4,
            'distance_meters': 350.0,
          }
        ],
        'count': 1,
        'suggestions': [],
        'message': null,
      };

      final model = SearchResultModel.fromJson(json);
      expect(model.count, equals(1));
      expect(model.places.length, equals(1));
      expect(model.places.first.nom, equals('Pharmacie Yako'));
      expect(model.places.first.distanceMeters, equals(350.0));
      expect(model.suggestions, isEmpty);
      expect(model.message, isNull);
    });

    test('SearchResultModel désérialisation JSON résultat vide avec suggestions', () {
      final json = {
        'results': [],
        'count': 0,
        'suggestions': ['Pharmacie Yako', 'CHU Yalgado', 'Total Tampouy'],
        'message': 'Aucun lieu trouvé pour « xyz »',
      };

      final model = SearchResultModel.fromJson(json);
      expect(model.count, equals(0));
      expect(model.places, isEmpty);
      expect(model.suggestions.length, equals(3));
      expect(model.suggestions.first, equals('Pharmacie Yako'));
      expect(model.message, contains('Aucun lieu trouvé'));
    });
  });
}
