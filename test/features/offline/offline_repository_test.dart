import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/features/offline/data/repositories/offline_repository.dart';

class MockApiClient extends Mock implements ApiClient {}

void main() {
  late MockApiClient mockApiClient;
  late OfflineRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    repository = OfflineRepository(apiClient: mockApiClient);
  });

  group('OfflineRepository Tests', () {
    test('getAvailablePacks récupère les 5 packs du Burkina', () async {
      when(() => mockApiClient.get<dynamic>(ApiEndpoints.offlinePacks))
          .thenAnswer((_) async => Response(
                requestOptions: RequestOptions(path: ApiEndpoints.offlinePacks),
                statusCode: 200,
                data: [
                  {
                    'region_id': 'centre-ouagadougou',
                    'nom_region': 'Région du Centre',
                    'description': 'Ouaga',
                    'taille_octets': 47185920,
                    'taille_mo': 45.0,
                    'version': '2026.09.1',
                    'sha256_checksum': 'abc',
                  },
                ],
              ));

      final result = await repository.getAvailablePacks();

      expect(result.length, 1);
      expect(result.first.regionId, 'centre-ouagadougou');
      expect(result.first.tailleMo, 45.0);
    });

    test('getRegionPois exporte les lieux compacts de la région', () async {
      when(() => mockApiClient.get<dynamic>(
            ApiEndpoints.offlinePackPois('centre-ouagadougou'),
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(
                path: ApiEndpoints.offlinePackPois('centre-ouagadougou')),
            statusCode: 200,
            data: {
              'region_id': 'centre-ouagadougou',
              'version': '2026.09.1',
              'total_pois': 2,
              'pois': [
                {
                  'id': 1,
                  'nom': 'Total Échangeur de l\'Est',
                  'categorie_slug': 'station-service',
                  'latitude': 12.361,
                  'longitude': -1.485,
                },
              ],
            },
          ));

      final result = await repository.getRegionPois('centre-ouagadougou');

      expect(result.regionId, 'centre-ouagadougou');
      expect(result.totalPois, 2);
      expect(result.pois.length, 1);
      expect(result.pois.first.nom, 'Total Échangeur de l\'Est');
    });

    test('getPackDownloadUrl génère l\'URL correcte', () {
      final url = repository.getPackDownloadUrl('centre-ouagadougou');
      expect(url, contains('/offline/packs/centre-ouagadougou/download'));
    });
  });
}
