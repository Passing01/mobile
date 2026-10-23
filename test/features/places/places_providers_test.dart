import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';

void main() {
  group('Places Providers Tests', () {
    test('SelectedCategoryNotifier bascule (toggle) correctement', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedCategorySlugProvider), isNull);

      container.read(selectedCategorySlugProvider.notifier).selectCategory('pharmacie');
      expect(container.read(selectedCategorySlugProvider), 'pharmacie');

      // Taper à nouveau sur la même catégorie la désélectionne
      container.read(selectedCategorySlugProvider.notifier).selectCategory('pharmacie');
      expect(container.read(selectedCategorySlugProvider), isNull);

      // Sélectionner une autre
      container.read(selectedCategorySlugProvider.notifier).selectCategory('station-service');
      expect(container.read(selectedCategorySlugProvider), 'station-service');

      container.read(selectedCategorySlugProvider.notifier).clear();
      expect(container.read(selectedCategorySlugProvider), isNull);
    });

    test('CurrentLocationNotifier met à jour la position', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      final initial = container.read(currentLocationProvider);
      expect(initial.lat, 12.3685);
      expect(initial.lon, -1.5271);

      container.read(currentLocationProvider.notifier).updateLocation(11.1772, -4.2979, 'Bobo-Dioulasso');
      final updated = container.read(currentLocationProvider);
      expect(updated.lat, 11.1772);
      expect(updated.lon, -4.2979);
      expect(updated.label, 'Bobo-Dioulasso');
    });

    test('SelectedPlaceNotifier gère la sélection d\'un lieu', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(selectedPlaceProvider), isNull);

      const testPlace = PlaceModel(
        id: 1,
        nom: 'Pharmacie du 1200 Logements',
        categorieId: 1,
        latitude: 12.3688,
        longitude: -1.4988,
      );

      container.read(selectedPlaceProvider.notifier).select(testPlace);
      expect(container.read(selectedPlaceProvider), testPlace);

      container.read(selectedPlaceProvider.notifier).clear();
      expect(container.read(selectedPlaceProvider), isNull);
    });

    test('SearchQueryNotifier met à jour et efface la requête', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      expect(container.read(searchQueryProvider), isEmpty);

      container.read(searchQueryProvider.notifier).setQuery('Pharmacie');
      expect(container.read(searchQueryProvider), 'Pharmacie');

      container.read(searchQueryProvider.notifier).clear();
      expect(container.read(searchQueryProvider), isEmpty);
    });
  });
}
