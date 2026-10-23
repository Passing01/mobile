import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/core/widgets/loaders/app_shimmer.dart';

void main() {
  group('Shimmer & Skeleton Loader Tests', () {
    testWidgets('PoiCardShimmer s\'affiche correctement', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PoiCardShimmer(),
          ),
        ),
      );

      expect(find.byType(PoiCardShimmer), findsOneWidget);
      expect(find.byType(AppShimmer), findsOneWidget);
    });

    testWidgets('RouteModeShimmer s\'affiche correctement', (WidgetTester tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: RouteModeShimmer(),
          ),
        ),
      );

      expect(find.byType(RouteModeShimmer), findsOneWidget);
      expect(find.byType(AppShimmer), findsOneWidget);
    });
  });
}
