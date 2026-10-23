import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/reports/data/models/create_report_request.dart';
import 'package:qvgestion_mobile/features/reports/data/models/report_model.dart';
import 'package:qvgestion_mobile/features/reports/data/models/report_type_model.dart';

void main() {
  group('ReportTypeModel Tests', () {
    test('Désérialisation correcte depuis JSON', () {
      final json = {
        'type_incident': 'flooding',
        'label': 'Inondation / Caniveau débordé',
        'description': 'Voie submergée par les eaux de pluie.',
        'default_duration_hours': 8.0,
      };

      final type = ReportTypeModel.fromJson(json);

      expect(type.typeIncident, equals('flooding'));
      expect(type.label, equals('Inondation / Caniveau débordé'));
      expect(type.defaultDurationHours, equals(8.0));
      expect(type.iconData, isNotNull);
      expect(type.color, isNotNull);
    });
  });

  group('ReportModel Tests', () {
    test('Désérialisation d\'un signalement actif avec votes', () {
      final json = {
        'id': 10,
        'type_incident': 'pothole',
        'description': 'Trou béant devant la station Shell',
        'latitude': 12.3685,
        'longitude': -1.5271,
        'adresse': 'Avenue Bassawarga',
        'quartier': 'Pissy',
        'ville': 'Ouagadougou',
        'statut': 'active',
        'score_confiance': 3,
        'upvotes': 3,
        'downvotes': 0,
        'created_at': '2026-10-09T20:00:00Z',
        'expires_at': '2026-10-23T20:00:00Z',
        'is_active': true,
        'user_vote': 1,
      };

      final report = ReportModel.fromJson(json);

      expect(report.id, equals(10));
      expect(report.typeIncident, equals('pothole'));
      expect(report.label, equals('Nid-de-poule dangereux'));
      expect(report.scoreConfiance, equals(3));
      expect(report.upvotes, equals(3));
      expect(report.hasUserUpvoted, isTrue);
      expect(report.hasUserDownvoted, isFalse);
      expect(report.isActive, isTrue);
    });

    test('copyWith met à jour les champs et les votes', () {
      final report = ReportModel(
        id: 1,
        typeIncident: 'road_closed',
        latitude: 12.36,
        longitude: -1.52,
        createdAt: DateTime.now(),
        upvotes: 1,
        downvotes: 0,
      );

      final updated = report.copyWith(
        upvotes: 2,
        scoreConfiance: 2,
        userVote: 1,
      );

      expect(updated.upvotes, equals(2));
      expect(updated.scoreConfiance, equals(2));
      expect(updated.hasUserUpvoted, isTrue);
    });
  });

  group('CreateReportRequest Tests', () {
    test('toJson sérialise correctement le payload', () {
      const request = CreateReportRequest(
        typeIncident: 'flooding',
        description: 'Caniveau débordé',
        latitude: 12.35,
        longitude: -1.51,
        quartier: 'Gounghin',
        ville: 'Ouagadougou',
      );

      final json = request.toJson();

      expect(json['type_incident'], equals('flooding'));
      expect(json['description'], equals('Caniveau débordé'));
      expect(json['latitude'], equals(12.35));
      expect(json['longitude'], equals(-1.51));
      expect(json['quartier'], equals('Gounghin'));
      expect(json['ville'], equals('Ouagadougou'));
    });
  });
}
