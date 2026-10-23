import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/routes/data/models/route_model.dart';

void main() {
  group('RouteModel & ManeuverModel Tests', () {
    test('fromJson désérialise fidèlement la réponse du calcul d\'itinéraire', () {
      final json = {
        'mode': 'motorcycle',
        'distance_meters': 841.0,
        'duration_seconds': 86,
        'duration_formatted': '1 min',
        'geometry': [
          [12.3685, -1.5271],
          [12.36768, -1.52612],
          [12.3644, -1.5222],
        ],
        'bounding_box': [12.3644, -1.5271, 12.3685, -1.5222],
        'maneuvers': [
          {
            'order': 1,
            'instruction': 'Prenez la route en direction de Grand Marché',
            'street_name': 'Voie principale',
            'maneuver_type': 'depart',
            'distance_meters': 336.4,
            'duration_seconds': 34,
            'location': {
              'lat': 12.3685,
              'lon': -1.5271,
              'name': '1200 Logements',
            },
          },
          {
            'order': 2,
            'instruction': 'Vous êtes arrivé',
            'maneuver_type': 'arrive',
            'distance_meters': 84.1,
            'duration_seconds': 8,
            'location': {
              'lat': 12.3644,
              'lon': -1.5222,
            },
          }
        ],
        'engine': 'geodesic_fallback',
      };

      final route = RouteModel.fromJson(json);

      expect(route.mode, 'motorcycle');
      expect(route.distanceMeters, 841.0);
      expect(route.durationSeconds, 86);
      expect(route.durationFormatted, '1 min');
      expect(route.distanceFormatted, '841 m');
      expect(route.geometry.length, 3);
      expect(route.boundingBox, [12.3644, -1.5271, 12.3685, -1.5222]);
      expect(route.maneuvers.length, 2);
      expect(route.maneuvers.first.instruction, 'Prenez la route en direction de Grand Marché');
      expect(route.maneuvers.first.location.name, '1200 Logements');
      expect(route.engine, 'geodesic_fallback');
    });

    test('distanceFormatted affiche les km lorsque la distance >= 1000m', () {
      const longRoute = RouteModel(
        mode: 'auto',
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
        'mode': 'motorcycle',
        'label': 'Moto / Deux-roues',
        'description': 'Idéal pour Ouagadougou',
        'average_speed_kmh': 35.0,
      };

      final mode = TransportModeInfoModel.fromJson(json);
      expect(mode.mode, 'motorcycle');
      expect(mode.label, 'Moto / Deux-roues');
      expect(mode.averageSpeedKmh, 35.0);
    });
  });
}
