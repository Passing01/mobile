import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/features/reports/data/models/create_report_request.dart';
import 'package:qvgestion_mobile/features/reports/data/repositories/reports_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late ReportsRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = ReportsRepository(apiClient: mockApiClient);
  });

  group('ReportsRepository Tests', () {
    test('getReportTypes retourne la typologie des incidents', () async {
      when(() => mockApiClient.get<dynamic>(ApiEndpoints.reportsTypes))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ApiEndpoints.reportsTypes),
                statusCode: 200,
                data: [
                  {
                    'type_incident': 'pothole',
                    'label': 'Nid-de-poule',
                    'description': 'Trou sur la chaussée',
                    'default_duration_hours': 336.0,
                  },
                  {
                    'type_incident': 'flooding',
                    'label': 'Inondation',
                    'description': 'Caniveau débordé',
                    'default_duration_hours': 8.0,
                  },
                ],
              ));

      final result = await repository.getReportTypes();

      expect(result.length, 2);
      expect(result.first.typeIncident, 'pothole');
      expect(result.last.typeIncident, 'flooding');
    });

    test('getActiveReports récupère la liste des obstacles actifs', () async {
      when(() => mockApiClient.get<dynamic>(ApiEndpoints.reportsActive,
              queryParameters: any(named: 'queryParameters')))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ApiEndpoints.reportsActive),
                statusCode: 200,
                data: [
                  {
                    'id': 1,
                    'type_incident': 'road_closed',
                    'latitude': 12.3685,
                    'longitude': -1.5271,
                    'statut': 'active',
                    'score_confiance': 2,
                    'upvotes': 2,
                    'downvotes': 0,
                    'created_at': '2026-10-09T20:00:00Z',
                    'is_active': true,
                  },
                ],
              ));

      final result = await repository.getActiveReports();

      expect(result.length, 1);
      expect(result.first.id, 1);
      expect(result.first.typeIncident, 'road_closed');
      expect(result.first.scoreConfiance, 2);
    });

    test('createReport soumet un nouvel obstacle', () async {
      const request = CreateReportRequest(
        typeIncident: 'flooding',
        description: 'Caniveau débordé',
        latitude: 12.35,
        longitude: -1.51,
        quartier: 'Pissy',
      );

      when(() => mockApiClient.post<dynamic>(
            ApiEndpoints.reports,
            data: request.toJson(),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.reports),
            statusCode: 201,
            data: {
              'id': 5,
              'type_incident': 'flooding',
              'description': 'Caniveau débordé',
              'latitude': 12.35,
              'longitude': -1.51,
              'quartier': 'Pissy',
              'statut': 'active',
              'score_confiance': 1,
              'upvotes': 1,
              'downvotes': 0,
              'created_at': '2026-10-09T22:00:00Z',
              'is_active': true,
              'user_vote': 1,
            },
          ));

      final result = await repository.createReport(request);

      expect(result.id, 5);
      expect(result.typeIncident, 'flooding');
      expect(result.upvotes, 1);
      expect(result.userVote, 1);
    });

    test('voteReport transmet le vote de confirmation (+1)', () async {
      when(() => mockApiClient.post<dynamic>(
            ApiEndpoints.reportVote(5),
            data: {'vote': 1},
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.reportVote(5)),
            statusCode: 200,
            data: {
              'id': 5,
              'type_incident': 'flooding',
              'latitude': 12.35,
              'longitude': -1.51,
              'statut': 'active',
              'score_confiance': 2,
              'upvotes': 2,
              'downvotes': 0,
              'created_at': '2026-10-09T22:00:00Z',
              'is_active': true,
              'user_vote': 1,
            },
          ));

      final result = await repository.voteReport(5, 1);

      expect(result.id, 5);
      expect(result.upvotes, 2);
      expect(result.scoreConfiance, 2);
    });
  });
}
