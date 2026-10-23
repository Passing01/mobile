import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/enriched_maneuver_model.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/enriched_route_model.dart';
import 'package:qvgestion_mobile/features/guidance/data/models/landmark_model.dart';

void main() {
  group('LandmarkModel Tests', () {
    test('Désérialisation et restitution multilingue du repère', () {
      final json = {
        'id': 1,
        'nom': 'Échangeur de l\'Est',
        'nom_moore': 'Yaarã wĩndg pʋgẽ échangeur',
        'nom_dioula': 'Kɔrɔn fɛ échangeur',
        'latitude': 12.3685,
        'longitude': -1.5020,
        'importance': 5,
        'visibilite_metres': 120.0,
        'type_repere': 'monument',
        'description': 'Grand échangeur de l\'Est à Ouagadougou',
      };

      final landmark = LandmarkModel.fromJson(json);

      expect(landmark.id, equals(1));
      expect(landmark.nom, equals('Échangeur de l\'Est'));
      expect(landmark.localizedName('mos'), equals('Yaarã wĩndg pʋgẽ échangeur'));
      expect(landmark.localizedName('diu'), equals('Kɔrɔn fɛ échangeur'));
      expect(landmark.localizedName('fr'), equals('Échangeur de l\'Est'));
      expect(landmark.importance, equals(5));
      expect(landmark.iconData, isNotNull);
    });
  });

  group('EnrichedManeuverModel Tests', () {
    test('Désérialisation d\'une manœuvre enrichie avec repère et audio', () {
      final json = {
        'order': 2,
        'original_instruction': 'Tournez à gauche',
        'localized_instruction': 'Pharmacie 1200 Logements poore, gilli wĩndg-goabga',
        'language': 'mos',
        'maneuver_type': 'turn_left',
        'has_landmark': true,
        'landmark_name': 'Pharmacie 1200 Logements',
        'distance_meters': 1200.0,
        'duration_seconds': 140,
        'audio_sound_id': 'mos_turn_left',
        'audio_url': '/api/v1/guidance/audio/mos_turn_left.wav',
      };

      final maneuver = EnrichedManeuverModel.fromJson(json);

      expect(maneuver.order, equals(2));
      expect(maneuver.hasLandmark, isTrue);
      expect(maneuver.landmarkName, equals('Pharmacie 1200 Logements'));
      expect(maneuver.localizedInstruction, contains('Pharmacie 1200 Logements poore'));
      expect(maneuver.distanceFormatted, equals('1.2 km'));
      expect(maneuver.durationFormatted, equals('2 min'));
      expect(maneuver.audioSoundId, equals('mos_turn_left'));
      expect(maneuver.iconData, isNotNull);
    });
  });

  group('EnrichedRouteModel Tests', () {
    test('Désérialisation complète d\'un itinéraire enrichi', () {
      final json = {
        'mode': 'motorcycle',
        'total_distance_meters': 4200.0,
        'total_duration_formatted': '8 min',
        'language': 'mos',
        'enriched_maneuvers': [
          {
            'order': 1,
            'original_instruction': 'Prenez la route',
            'localized_instruction': 'Rɩk sorã',
            'language': 'mos',
            'maneuver_type': 'depart',
            'has_landmark': false,
            'distance_meters': 400.0,
            'duration_seconds': 50,
          },
        ],
      };

      final route = EnrichedRouteModel.fromJson(json);

      expect(route.mode, equals('motorcycle'));
      expect(route.totalDurationFormatted, equals('8 min'));
      expect(route.distanceFormatted, equals('4.2 km'));
      expect(route.enrichedManeuvers.length, equals(1));
      expect(route.enrichedManeuvers.first.maneuverType, equals('depart'));
    });
  });
}
