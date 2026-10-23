import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/places/data/models/category_model.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/places/presentation/widgets/places_search_sheet.dart';

void main() {
  const samplePlace = PlaceModel(
    id: 1,
    nom: 'Pharmacie du 1200 Logements',
    categorieId: 1,
    latitude: 12.3688,
    longitude: -1.4988,
    quartier: '1200 Logements',
    horaires: '24h/24',
    distanceMeters: 350.0,
    categorie: CategoryModel(
      id: 1,
      nom: 'Pharmacie',
      slug: 'pharmacie',
      icone: 'local_pharmacy',
    ),
  );

  testWidgets('PlacesSearchSheet affiche les lieux à proximité par défaut',
      (WidgetTester tester) async {
    PlaceModel? selected;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearbyPlacesProvider.overrideWith((ref) async => [samplePlace]),
          searchResultsProvider.overrideWith((ref) async => []),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PlacesSearchSheet(
              onPlaceSelected: (p) => selected = p,
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Vérifie le titre de la section par défaut
    expect(find.text('Lieux à proximité à Ouagadougou'), findsOneWidget);
    expect(find.text('Pharmacie du 1200 Logements'), findsOneWidget);
    expect(find.text('350 m'), findsOneWidget);

    // Clic sur le lieu
    await tester.tap(find.text('Pharmacie du 1200 Logements'));
    await tester.pumpAndSettle();

    expect(selected, samplePlace);
  });

  testWidgets('PlacesSearchSheet affiche les résultats quand une requête est tapée',
      (WidgetTester tester) async {
    const searchMatch = PlaceModel(
      id: 4,
      nom: 'Grand Marché Rood-Woko',
      categorieId: 3,
      latitude: 12.3685,
      longitude: -1.5222,
      quartier: 'Centre-Ville',
      distanceMeters: 532.0,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nearbyPlacesProvider.overrideWith((ref) async => [samplePlace]),
          searchResultsProvider.overrideWith((ref) async => [searchMatch]),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: PlacesSearchSheet(
              onPlaceSelected: (_) {},
            ),
          ),
        ),
      ),
    );

    await tester.pumpAndSettle();

    // Saisie d'un texte de recherche
    await tester.enterText(find.byType(TextField), 'Rood');
    await tester.pumpAndSettle();

    // Les résultats de recherche s'affichent
    expect(find.text('Grand Marché Rood-Woko'), findsOneWidget);
    expect(find.text('532 m'), findsOneWidget);
  });
}
