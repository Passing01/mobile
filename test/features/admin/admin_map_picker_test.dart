import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:qvgestion_mobile/features/admin/presentation/widgets/admin_map_point_picker_dialog.dart';

void main() {
  testWidgets('AdminMapPointPickerDialog affiche la carte, les presets de villes et valide la position',
      (WidgetTester tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);

    LatLng? selected;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                key: const Key('open_picker_btn'),
                onPressed: () async {
                  selected = await AdminMapPointPickerDialog.pickPoint(
                    context,
                    initialPoint: const LatLng(12.3680, -1.5270),
                    title: 'Sélectionner un repère',
                  );
                },
                child: const Text('Ouvrir Picker'),
              ),
            ),
          ),
        ),
      ),
    );

    // Ouvrir le picker
    await tester.tap(find.byKey(const Key('open_picker_btn')));
    await tester.pumpAndSettle();

    // Vérifier les éléments de l'interface
    expect(find.text('Sélectionner un repère'), findsOneWidget);
    expect(find.text('Ouagadougou'), findsOneWidget);
    expect(find.text('Bobo-Dioulasso'), findsOneWidget);
    expect(find.text('Koudougou'), findsOneWidget);

    // Simuler le clic sur la ville de Bobo-Dioulasso
    await tester.tap(find.text('Bobo-Dioulasso'));
    await tester.pumpAndSettle();

    // Vérifier la présence du bouton de confirmation
    final confirmFinder = find.byKey(const Key('admin_map_point_picker_confirm'));
    expect(confirmFinder, findsOneWidget);

    // Confirmer
    await tester.tap(confirmFinder);
    await tester.pumpAndSettle();

    // Vérifier que la position sélectionnée a bien été retournée (position de Bobo-Dioulasso)
    expect(selected, isNotNull);
    expect(selected!.latitude, closeTo(11.1771, 0.001));
    expect(selected!.longitude, closeTo(-4.2974, 0.001));
  });
}
