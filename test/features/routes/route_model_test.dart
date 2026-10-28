import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

void main() {
  group('RouteModel & ManeuverModel Tests (Étape 7)', () {
    test('fromJson désérialise fidèlement la réponse Valhalla POST /api/v1/routes', () {
      final json = {
        'engine': 'valhalla',
        'mode': 'moto',
        'distance_m': 669.0,
        'duration_s': 57.704,
        'legs': 1,
        'geometry': {
          'type': 'LineString',
          'coordinates': [
            [-1.54815, 12.356232],
            [-1.547888, 12.356393],
            [-1.542907, 12.359387]
          ]
        },
        'maneuvers': [
          {
            'type': 2,
            'instruction': 'Conduisez vers le nord-est sur Avenue Kadiogo.',
            'street_names': ['Avenue Kadiogo'],
            'lat': 12.356232,
            'lng': -1.54815,
            'length_m': 669.0,
            'time_s': 57.704
          },
          {
            'type': 5,
            'instruction': 'Votre destination est sur la droite.',
            'street_names': [],
            'lat': 12.359387,
            'lng': -1.542907,
            'length_m': 0.0,
            'time_s': 0.0
          }
        ],
        'start_snap_m': 31
      };

      final route = RouteModel.fromJson(json);

      expect(route.engine, 'valhalla');
      expect(route.mode, 'moto');
      expect(route.distanceMeters, 669.0);
      expect(route.durationSeconds, 58);
      expect(route.legs, 1);
      expect(route.geometry.length, 3);
      expect(route.geometry.first, [-1.54815, 12.356232]);
      expect(route.maneuvers.length, 2);
      expect(route.maneuvers.first.instruction,
          'Conduisez vers le nord-est sur Avenue Kadiogo.');
      expect(route.maneuvers.first.streetName, 'Avenue Kadiogo');
      expect(route.maneuvers.first.distanceMeters, 669.0);
      expect(route.maneuvers.first.location.lat, 12.356232);
      expect(route.maneuvers.first.location.lon, -1.54815);
      expect(route.startSnapM, 31);
      expect(route.distanceFormatted, '669 m');
    });

    test('distanceFormatted affiche les km lorsque la distance >= 1000m', () {
      const longRoute = RouteModel(
        mode: 'voiture',
        distanceMeters: 7420.0,
        durationSeconds: 960,
        durationFormatted: '16 min',
        geometry: [],
        boundingBox: [],
        maneuvers: [],
        engine: 'valhalla',
      );

      expect(longRoute.distanceFormatted, '7.4 km');
    });

    test('TransportModeInfoModel désérialise correctement', () {
      final json = {
        'mode': 'moto',
        'label': 'Moto Urbaine',
        'description': 'Idéal pour Ouagadougou',
        'average_speed_kmh': 35.0,
      };

      final mode = TransportModeInfoModel.fromJson(json);
      expect(mode.mode, 'moto');
      expect(mode.label, 'Moto Urbaine');
      expect(mode.averageSpeedKmh, 35.0);
    });
  });
}
