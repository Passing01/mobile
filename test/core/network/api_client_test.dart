import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_exceptions.dart';
import 'package:qvgestion_mobile/core/storage/token_storage.dart';

class MockDio extends Mock implements Dio {}
class MockTokenStorage extends Mock implements TokenStorage {}

void main() {
  late MockDio mockDio;
  late MockTokenStorage mockTokenStorage;
  late ApiClient apiClient;

  setUp(() {
    mockDio = MockDio();
    mockTokenStorage = MockTokenStorage();
    when(() => mockDio.interceptors).thenReturn(Interceptors());

    apiClient = ApiClient(
      tokenStorage: mockTokenStorage,
      dio: mockDio,
    );
  });

  group('ApiClient Tests', () {
    test('get() effectue un appel GET avec succès', () async {
      final dummyResponse = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/places'),
        statusCode: 200,
        data: {'places': []},
      );

      when(() => mockDio.get<Map<String, dynamic>>(
            '/places',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          )).thenAnswer((_) async => dummyResponse);

      final response = await apiClient.get<Map<String, dynamic>>('/places');

      expect(response.statusCode, equals(200));
      expect(response.data, equals({'places': []}));
    });

    test('get() capture DioException et lance ApiException correspondante', () async {
      when(() => mockDio.get<dynamic>(
            '/places',
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/places'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

      expect(
        () async => await apiClient.get('/places'),
        throwsA(isA<NetworkTimeoutException>()),
      );
    });

    test('post() transmet le body et intercepte les erreurs 422', () async {
      when(() => mockDio.post<dynamic>(
            '/auth/login',
            data: any(named: 'data'),
            queryParameters: any(named: 'queryParameters'),
            options: any(named: 'options'),
            cancelToken: any(named: 'cancelToken'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: '/auth/login'),
          type: DioExceptionType.badResponse,
          response: Response(
            requestOptions: RequestOptions(path: '/auth/login'),
            statusCode: 422,
            data: {
              'detail': [
                {'loc': ['body', 'mot_de_passe'], 'msg': 'Champ obligatoire'}
              ]
            },
          ),
        ),
      );

      expect(
        () async => await apiClient.post('/auth/login', data: {}),
        throwsA(isA<ValidationException>()),
      );
    });
  });
}
