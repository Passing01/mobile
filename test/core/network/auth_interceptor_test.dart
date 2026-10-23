import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/network/auth_interceptor.dart';
import 'package:qvgestion_mobile/core/storage/token_storage.dart';

class MockTokenStorage extends Mock implements TokenStorage {}
class MockDio extends Mock implements Dio {}
class MockRequestInterceptorHandler extends Mock implements RequestInterceptorHandler {}
class MockErrorInterceptorHandler extends Mock implements ErrorInterceptorHandler {}

void main() {
  late MockTokenStorage mockTokenStorage;
  late MockDio mockDio;
  late MockDio mockRefreshDio;
  late AuthInterceptor interceptor;
  bool tokenExpiredCallbackCalled = false;

  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
    registerFallbackValue(
      DioException(requestOptions: RequestOptions(path: '')),
    );
  });

  setUp(() {
    mockTokenStorage = MockTokenStorage();
    mockDio = MockDio();
    mockRefreshDio = MockDio();
    tokenExpiredCallbackCalled = false;

    interceptor = AuthInterceptor(
      tokenStorage: mockTokenStorage,
      dio: mockDio,
      refreshDio: mockRefreshDio,
      onTokenExpired: () {
        tokenExpiredCallbackCalled = true;
      },
    );
  });

  group('AuthInterceptor - onRequest', () {
    test('Injecte le token Bearer et l\'en-tête gzip quand le token est présent', () async {
      when(() => mockTokenStorage.getAccessToken())
          .thenAnswer((_) async => 'valid_access_token');

      final options = RequestOptions(path: '/places/nearby');
      final handler = MockRequestInterceptorHandler();

      when(() => handler.next(any())).thenReturn(null);

      await interceptor.onRequest(options, handler);

      expect(options.headers['Authorization'], equals('Bearer valid_access_token'));
      expect(options.headers['Accept-Encoding'], equals('gzip'));
      expect(options.headers['Accept'], equals('application/json'));
      verify(() => handler.next(options)).called(1);
    });

    test('N\'injecte pas d\'Authorization si le token est absent', () async {
      when(() => mockTokenStorage.getAccessToken())
          .thenAnswer((_) async => null);

      final options = RequestOptions(path: '/places/nearby');
      final handler = MockRequestInterceptorHandler();

      when(() => handler.next(any())).thenReturn(null);

      await interceptor.onRequest(options, handler);

      expect(options.headers['Authorization'], isNull);
      expect(options.headers['Accept-Encoding'], equals('gzip'));
      verify(() => handler.next(options)).called(1);
    });
  });

  group('AuthInterceptor - onError (Renouvellement 401)', () {
    test('Ignore le 401 si la requête cible une route d\'authentification', () async {
      final options = RequestOptions(path: ApiEndpoints.login);
      final error = DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 401),
      );
      final handler = MockErrorInterceptorHandler();

      when(() => handler.next(any())).thenReturn(null);

      await interceptor.onError(error, handler);

      verifyNever(() => mockTokenStorage.getRefreshToken());
      verify(() => handler.next(error)).called(1);
    });

    test('Déconnecte si 401 mais aucun refresh token disponible', () async {
      final options = RequestOptions(path: '/users/me');
      final error = DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 401),
      );
      final handler = MockErrorInterceptorHandler();

      when(() => mockTokenStorage.getRefreshToken()).thenAnswer((_) async => null);
      when(() => mockTokenStorage.clearTokens()).thenAnswer((_) async {});
      when(() => handler.next(any())).thenReturn(null);

      await interceptor.onError(error, handler);

      verify(() => mockTokenStorage.clearTokens()).called(1);
      expect(tokenExpiredCallbackCalled, isTrue);
      verify(() => handler.next(error)).called(1);
    });

    test('Rafraîchit le jeton avec succès et rejoue la requête initiale', () async {
      final options = RequestOptions(path: '/users/me');
      final error = DioException(
        requestOptions: options,
        response: Response(requestOptions: options, statusCode: 401),
      );
      final handler = MockErrorInterceptorHandler();

      when(() => mockTokenStorage.getRefreshToken())
          .thenAnswer((_) async => 'old_refresh_token');
      when(() => mockTokenStorage.saveTokens(
            accessToken: 'new_access_token',
            refreshToken: 'new_refresh_token',
          )).thenAnswer((_) async {});

      when(() => mockRefreshDio.post(
            ApiEndpoints.refresh,
            data: {'refresh_token': 'old_refresh_token'},
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.refresh),
            statusCode: 200,
            data: {
              'access_token': 'new_access_token',
              'refresh_token': 'new_refresh_token',
              'token_type': 'bearer',
            },
          ));

      final retriedResponse = Response(
        requestOptions: options,
        statusCode: 200,
        data: {'id': 1, 'nom': 'Rasmané'},
      );

      when(() => mockDio.fetch(options)).thenAnswer((_) async => retriedResponse);
      when(() => handler.resolve(retriedResponse)).thenReturn(null);

      await interceptor.onError(error, handler);

      verify(() => mockTokenStorage.saveTokens(
            accessToken: 'new_access_token',
            refreshToken: 'new_refresh_token',
          )).called(1);
      expect(options.headers['Authorization'], equals('Bearer new_access_token'));
      verify(() => mockDio.fetch(options)).called(1);
      verify(() => handler.resolve(retriedResponse)).called(1);
    });
  });
}
