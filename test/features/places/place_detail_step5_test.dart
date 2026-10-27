import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/data/models/category_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/places/presentation/widgets/place_detail_sheet.dart';
import 'package:qvgestion_mobile/features/map/presentation/screens/home_map_screen.dart';
import 'package:qvgestion_mobile/features/routes/presentation/providers/routes_providers.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

class FakeActiveRouteNotifier extends ActiveRouteNotifier {
  final RouteModel? initialRoute;
  FakeActiveRouteNotifier(this.initialRoute);

  @override
  AsyncValue<RouteModel?> build() {
    return AsyncValue.data(initialRoute);
  }

  @override
  Future<RouteModel?> calculate({
    required CoordinateModel origin,
    required CoordinateModel destination,
    required String mode,
  }) async {
    state = AsyncValue.data(initialRoute);
    return initialRoute;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const sampleCategory = CategoryModel(
    id: 1,
    nom: 'Pharmacie',
    slug: 'pharmacie',
    icone: 'local_pharmacy',
    color: '#10B981',
    labels: {'fr': 'Pharmacies de garde'},
  );

  const samplePlace = PlaceModel(
    id: 101,
    uuid: 'uuid-pharma-1',
    nom: 'Grande Pharmacie de la Paix',
    categorieId: 1,
    categorie: sampleCategory,
    adresse: 'Avenue de la Nation, Ouagadougou',
    horaires: 'Ouvert 24h/24',
    telephone: '+226 25 30 00 00',
    latitude: 12.3714,
    longitude: -1.5197,
  );

  const sampleMotoRoute = RouteModel(
    mode: 'motorcycle',
    distanceMeters: 841.0,
    durationSeconds: 86,
    durationFormatted: '11 min',
    geometry: [
      [12.3685, -1.5271],
      [12.3644, -1.5222],
    ],
    boundingBox: [12.3644, -1.5271, 12.3685, -1.5222],
    maneuvers: [
      ManeuverModel(
        order: 1,
        instruction: 'Prenez la voie de droite vers le carrefour',
        maneuverType: 'depart',
        distanceMeters: 250.0,
        durationSeconds: 30,
        location: CoordinateModel(lat: 12.3685, lon: -1.5271),
      ),
    ],
    engine: 'geodesic_fallback',
  );

  group('Étape 5 · PlaceDetailSheet Widget Tests', () {
    testWidgets('PlaceDetailSheet affiche le nom, catégorie, adresse, horaires et les 3 boutons',
        (WidgetTester tester) async {
      String? navSource;
      PlaceModel? navPlace;
      bool reported = false;
      bool closed = false;

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            placeDetailProvider('uuid-pharma-1').overrideWith((ref) async => samplePlace),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PlaceDetailSheet(
                placeId: 'uuid-pharma-1',
                onClose: () => closed = true,
                onNavigate: (place, source) {
                  navPlace = place;
                  navSource = source;
                },
                onReport: () => reported = true,
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // 1. Nom du lieu
      expect(find.text('Grande Pharmacie de la Paix'), findsOneWidget);

      // 2. Libellé de catégorie et adresse
      expect(find.text('Pharmacies de garde'), findsOneWidget);
      expect(find.text('Avenue de la Nation, Ouagadougou'), findsOneWidget);

      // 3. Horaires et téléphone
      expect(find.text('Ouvert 24h/24'), findsOneWidget);
      expect(find.text('+226 25 30 00 00'), findsOneWidget);

      // 4. Les 3 boutons requis : « Itinéraire », « Appeler », « Signaler »
      expect(find.text('Itinéraire'), findsOneWidget);
      expect(find.text('Appeler'), findsOneWidget);
      expect(find.byKey(const Key('btn_place_report')), findsOneWidget);

      // 5. Clic sur Itinéraire -> source: 'lieu touché'
      await tester.tap(find.text('Itinéraire'));
      await tester.pumpAndSettle();
      expect(navPlace?.id, equals(101));
      expect(navSource, equals('lieu touché'));

      // 6. Clic sur Signaler
      await tester.tap(find.byKey(const Key('btn_place_report')));
      await tester.pumpAndSettle();
      expect(reported, isTrue);

      // 7. Clic sur Fermer
      await tester.tap(find.byIcon(Icons.close_rounded));
      await tester.pumpAndSettle();
      expect(closed, isTrue);
    });

    testWidgets('PlaceDetailSheet affiche un état d\'erreur clair si le lieu est introuvable (jamais d\'écran vide)',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            placeDetailProvider('invalid-id').overrideWith(
              (ref) async => throw Exception('Lieu introuvable'),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: PlaceDetailSheet(
                placeId: 'invalid-id',
                onClose: () {},
                onNavigate: (place, source) {},
              ),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Erreur explicite affichée, avec bouton de réessai
      expect(find.text('Lieu introuvable'), findsOneWidget);
      expect(find.text('Réessayer'), findsOneWidget);
      expect(find.text('Fermer'), findsOneWidget);
    });
  });

  group('Étape 5 · HomeMapScreen Gesture & Pin Tests', () {
    testWidgets('Appui long pose une épingle et demande confirmation « Aller ici ? »',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            categoriesProvider.overrideWith((ref) async => [sampleCategory]),
            nearbyPlacesProvider.overrideWith((ref) async => [samplePlace]),
            selectedPlaceProvider.overrideWith(SelectedPlaceNotifier.new),
            activeRouteProvider.overrideWith(() => FakeActiveRouteNotifier(sampleMotoRoute)),
            multiModeRoutesProvider.overrideWith((ref) async => {
              'motorcycle': sampleMotoRoute,
            }),
          ],
          child: const MaterialApp(
            home: HomeMapScreen(),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Déclencher un appui long sur la carte dans la zone visible dégagée
      await tester.longPressAt(const Offset(200, 230));
      await tester.pumpAndSettle();

      // Le dialogue de confirmation apparaît avec « Aller ici ? »
      expect(find.text('Destination'), findsOneWidget);
      expect(find.text('Aller ici ?'), findsOneWidget);
      expect(find.byKey(const Key('btn_cancel_destination')), findsOneWidget);
      expect(find.byKey(const Key('btn_confirm_destination')), findsOneWidget);

      // Clic sur "Aller ici" pour confirmer
      await tester.tap(find.byKey(const Key('btn_confirm_destination')));
      await tester.pumpAndSettle();

      // Vérifier que la sélection du mode d'itinéraire s'ouvre
      expect(find.text('Choisir votre moyen de déplacement'), findsOneWidget);
    });
  });
}
