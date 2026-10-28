import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/core/services/route_service.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';
import 'package:qvgestion_mobile/features/routes/presentation/providers/routes_providers.dart';
import 'package:qvgestion_mobile/features/routes/presentation/screens/routes_screen.dart';

class MockRouteService extends Mock implements RouteService {}

void main() {
  testWidgets('RoutesScreen affiche les 3 modes et les champs départ/arrivée',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RoutesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Itinéraires & Navigation'), findsOneWidget);
    expect(find.text('Moto'), findsOneWidget);
    expect(find.text('Voiture'), findsOneWidget);
    expect(find.text('À pied'), findsOneWidget);
    expect(find.text('Calculer l\'itinéraire'), findsOneWidget);
    expect(find.text('Ajouter une étape (0/5)'), findsOneWidget);
  });

  testWidgets('RoutesScreen permet d\'ajouter et supprimer des étapes',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: RoutesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Ajouter une étape
    await tester.tap(find.text('Ajouter une étape (0/5)'));
    await tester.pumpAndSettle();

    expect(find.text('Étape 1'), findsOneWidget);
    expect(find.text('Ajouter une étape (1/5)'), findsOneWidget);

    // Supprimer l'étape
    await tester.tap(find.byIcon(Icons.remove_circle_outline));
    await tester.pumpAndSettle();

    expect(find.text('Étape 1'), findsNothing);
    expect(find.text('Ajouter une étape (0/5)'), findsOneWidget);
  });

  testWidgets('RoutesScreen affiche le bandeau d\'erreur en cas d\'échec API sans fallback',
      (tester) async {
    final container = ProviderContainer(
      overrides: [
        activeRouteProvider.overrideWith(() => FakeErrorRouteNotifier()),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: RoutesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('banner_route_error')), findsOneWidget);
    expect(find.text('Le calcul d\'itinéraire est indisponible'), findsOneWidget);
    expect(find.text('Démarrer'), findsNothing);
  });

  testWidgets('RoutesScreen affiche le tracé Valhalla et ses détails sur succès',
      (tester) async {
    const validRoute = RouteModel(
      engine: 'valhalla',
      mode: 'moto',
      distanceMeters: 669.0,
      durationSeconds: 58,
      durationFormatted: '1 min',
      legs: 2,
      geometry: [
        [-1.54815, 12.356232],
        [-1.542907, 12.359387],
      ],
      boundingBox: [12.3560, -1.5480, 12.3592, -1.5428],
      maneuvers: [
        ManeuverModel(
          order: 1,
          instruction: 'Conduisez vers le nord-est sur Avenue Kadiogo.',
          streetName: 'Avenue Kadiogo',
          maneuverType: 'straight',
          distanceMeters: 669.0,
          durationSeconds: 58,
          location: CoordinateModel(lat: 12.356232, lon: -1.54815),
        ),
      ],
    );

    final container = ProviderContainer(
      overrides: [
        activeRouteProvider.overrideWith(() => FakeSuccessRouteNotifier(validRoute)),
      ],
    );

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          home: RoutesScreen(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('1 min'), findsOneWidget);
    expect(find.textContaining('669 m • valhalla • 2 tronçons'), findsOneWidget);
    expect(find.text('Conduisez vers le nord-est sur Avenue Kadiogo.'), findsOneWidget);
    expect(find.text('Démarrer'), findsOneWidget);
  });
}

class FakeErrorRouteNotifier extends ActiveRouteNotifier {
  @override
  AsyncValue<RouteModel?> build() {
    return const AsyncValue.error(
      RoutingException(
        code: 'ENGINE_DOWN',
        message: 'Le calcul d\'itinéraire est indisponible',
        statusCode: 503,
      ),
      StackTrace.empty,
    );
  }
}

class FakeSuccessRouteNotifier extends ActiveRouteNotifier {
  final RouteModel mockRoute;
  FakeSuccessRouteNotifier(this.mockRoute);

  @override
  AsyncValue<RouteModel?> build() {
    return AsyncValue.data(mockRoute);
  }
}
