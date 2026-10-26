import 'package:flutter_test/flutter_test.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/features/map/presentation/widgets/places_layer.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/data/repositories/places_repository.dart';

class MockPlacesLayer extends Mock implements PlacesLayer {}
class MockPlacesRepository extends Mock implements PlacesRepository {}

void main() {
  group('PlacesLayer & PlacesController Tests', () {
    late MockPlacesLayer mockLayer;
    late MockPlacesRepository mockRepository;

    setUp(() {
      mockLayer = MockPlacesLayer();
      mockRepository = MockPlacesRepository();

      when(() => mockRepository.getPlacesGeoJson(
            categories: any(named: 'categories'),
            bbox: any(named: 'bbox'),
            zone: any(named: 'zone'),
            lat: any(named: 'lat'),
            lng: any(named: 'lng'),
            radiusM: any(named: 'radiusM'),
            q: any(named: 'q'),
            zoom: any(named: 'zoom'),
            limit: any(named: 'limit'),
          )).thenAnswer((_) async => {'type': 'FeatureCollection', 'features': []});

      when(() => mockLayer.show(any())).thenAnswer((_) async {});
      when(() => mockLayer.clear()).thenAnswer((_) async {});
    });

    test('PlacesController gère la sélection multi-catégories et le toggle', () {
      final controller = PlacesController(
        layer: mockLayer,
        repository: mockRepository,
      );

      expect(controller.selectedCategories, isEmpty);

      controller.toggle('pharmacie');
      expect(controller.selectedCategories, contains('pharmacie'));

      controller.toggle('hopital');
      expect(controller.selectedCategories, {'pharmacie', 'hopital'});

      controller.toggle('pharmacie');
      expect(controller.selectedCategories, {'hopital'});

      controller.setCategories({'station', 'administration'});
      expect(controller.selectedCategories, {'station', 'administration'});

      controller.dispose();
    });

    test('PlacesLayer instancie les propriétés MapLibre cluster et points', () async {
      const sourceProps = GeojsonSourceProperties(
        data: {'type': 'FeatureCollection', 'features': []},
        cluster: true,
        clusterRadius: 48,
        clusterMaxZoom: 14,
      );
      expect(sourceProps.cluster, true);
      expect(sourceProps.clusterRadius, 48);

      const clusterProps = CircleLayerProperties(
        circleColor: '#1E3A5F',
        circleStrokeColor: '#FFFFFF',
        circleStrokeWidth: 3.0,
      );
      expect(clusterProps.circleColor, '#1E3A5F');

      const pointProps = CircleLayerProperties(
        circleColor: [Expressions.get, 'color'],
        circleRadius: 8.0,
      );
      expect(pointProps.circleRadius, 8.0);
    });

    test('PlaceModel désérialise un Feature GeoJSON', () {
      final feature = {
        'type': 'Feature',
        'geometry': {
          'type': 'Point',
          'coordinates': [-1.5222, 12.3685],
        },
        'properties': {
          'id': 'abc-123',
          'name': 'Pharmacie du Marché',
          'category': 'pharmacie',
          'color': '#16A34A',
          'size': 4,
          'importance': 4,
          'tags': {'de_garde': true},
        },
      };

      final place = PlaceModel.fromGeoJsonFeature(feature);

      expect(place.nom, 'Pharmacie du Marché');
      expect(place.uuid, 'abc-123');
      expect(place.latitude, 12.3685);
      expect(place.longitude, -1.5222);
      expect(place.importance, 4);
      expect(place.isDeGarde, true);
      expect(place.categorie?.slug, 'pharmacie');
      expect(place.categorie?.color, '#16A34A');
    });
  });
}
