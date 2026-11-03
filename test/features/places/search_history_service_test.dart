import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/core/services/search_history_service.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';

void main() {
  group('SearchHistoryService Tests (Étape 11)', () {
    late SearchHistoryService service;

    setUp(() {
      service = SearchHistoryService(null); // Fallback mémoire
    });

    test('Initialement l\'historique est vide', () {
      expect(service.getHistory(), isEmpty);
    });

    test('Ajout d\'un terme de recherche (query) sans doublon', () async {
      await service.addQuery('Pharmacie Yako');
      await service.addQuery('Carburant');
      final list = service.getHistory();

      expect(list.length, equals(2));
      expect(list[0].label, equals('Carburant'));
      expect(list[0].kind, equals(SearchHistoryKind.query));
      expect(list[1].label, equals('Pharmacie Yako'));

      // Ré-ajouter 'Pharmacie Yako' doit le remonter en tête sans créer de doublon
      await service.addQuery('Pharmacie Yako');
      final updated = service.getHistory();
      expect(updated.length, equals(2));
      expect(updated[0].label, equals('Pharmacie Yako'));
      expect(updated[1].label, equals('Carburant'));
    });

    test('Ajout d\'un lieu consulté (place)', () async {
      const place = PlaceModel(
        id: 101,
        nom: 'Pharmacie de la Paix',
        categorieId: 1,
        latitude: 12.3850,
        longitude: -1.5020,
        quartier: 'Somgandé',
      );

      await service.addPlace(place);
      final list = service.getHistory();

      expect(list.length, equals(1));
      expect(list[0].kind, equals(SearchHistoryKind.place));
      expect(list[0].placeId, equals(101));
      expect(list[0].label, equals('Pharmacie de la Paix'));
      expect(list[0].latitude, equals(12.3850));
    });

    test('Ajout d\'un itinéraire récent (route) pour relance en 1 tap', () async {
      await service.addRoute(
        originName: 'Ma position GPS',
        originLat: 12.3714,
        originLon: -1.5197,
        destName: 'Total Échangeur du Nord',
        destLat: 12.3950,
        destLon: -1.5300,
        mode: 'moto',
      );

      final list = service.getHistory();
      expect(list.length, equals(1));
      expect(list[0].kind, equals(SearchHistoryKind.route));
      expect(list[0].label, contains('Ma position GPS ➔ Total Échangeur du Nord'));
      expect(list[0].routeData?['mode'], equals('moto'));
      expect(list[0].routeData?['destLat'], equals(12.3950));
    });

    test('Plafonnement strict à 20 entrées maximum', () async {
      for (int i = 1; i <= 25; i++) {
        await service.addQuery('Recherche $i');
      }

      final list = service.getHistory();
      expect(list.length, equals(SearchHistoryService.maxEntries));
      expect(list.length, equals(20));
      expect(list[0].label, equals('Recherche 25'));
      expect(list.last.label, equals('Recherche 6'));
    });

    test('Suppression d\'un élément spécifique', () async {
      await service.addQuery('A');
      await service.addQuery('B');
      final list = service.getHistory();
      final idToDelete = list.first.id;

      final after = await service.deleteItem(idToDelete);
      expect(after.length, equals(1));
      expect(after[0].label, equals('A'));
    });

    test('Effacement total de l\'historique', () async {
      await service.addQuery('Test 1');
      await service.addQuery('Test 2');
      expect(service.getHistory().length, equals(2));

      await service.clearHistory();
      expect(service.getHistory(), isEmpty);
    });
  });
}

