import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/places/data/models/category_model.dart';

void main() {
  group('CategoryModel Tests', () {
    test('fromJson & toJson désérialise et sérialise fidèlement', () {
      final json = {
        'id': 1,
        'nom': 'Pharmacie',
        'slug': 'pharmacie',
        'icone': 'local_pharmacy',
        'description': 'Pharmacies de garde',
      };

      final model = CategoryModel.fromJson(json);

      expect(model.id, 1);
      expect(model.nom, 'Pharmacie');
      expect(model.slug, 'pharmacie');
      expect(model.icone, 'local_pharmacy');
      expect(model.description, 'Pharmacies de garde');
      expect(model.iconData, Icons.local_pharmacy_rounded);

      final exportedJson = model.toJson();
      expect(exportedJson['id'], 1);
      expect(exportedJson['nom'], 'Pharmacie');
      expect(exportedJson['slug'], 'pharmacie');
    });

    test('iconData retourne les icônes adaptées pour chaque slug burkinabé', () {
      expect(
        const CategoryModel(id: 1, nom: 'Pharma', slug: 'pharmacie', icone: 'p').iconData,
        Icons.local_pharmacy_rounded,
      );
      expect(
        const CategoryModel(id: 2, nom: 'Total', slug: 'station-service', icone: 's').iconData,
        Icons.local_gas_station_rounded,
      );
      expect(
        const CategoryModel(id: 3, nom: 'Maquis', slug: 'maquis-restaurant', icone: 'm').iconData,
        Icons.restaurant_rounded,
      );
      expect(
        const CategoryModel(id: 4, nom: 'CSPS', slug: 'hopital-sante', icone: 'h').iconData,
        Icons.local_hospital_rounded,
      );
      expect(
        const CategoryModel(id: 5, nom: 'Banque', slug: 'banque-distributeur', icone: 'b').iconData,
        Icons.account_balance_rounded,
      );
      expect(
        const CategoryModel(id: 99, nom: 'Autre', slug: 'autre-inconnu', icone: 'x').iconData,
        Icons.place_rounded,
      );
    });
  });
}
