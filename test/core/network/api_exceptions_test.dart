import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/core/network/api_exceptions.dart';

void main() {
  group('ApiException.fromDioException Tests', () {
    final dummyRequestOptions = RequestOptions(path: '/test');

    test('Convertit connectionTimeout en NetworkTimeoutException', () {
      final dioException = DioException(
        requestOptions: dummyRequestOptions,
        type: DioExceptionType.connectionTimeout,
      );

      final exception = ApiException.fromDioException(dioException);
      expect(exception, isA<NetworkTimeoutException>());
    });

    test('Convertit connectionError en NetworkException', () {
      final dioException = DioException(
        requestOptions: dummyRequestOptions,
        type: DioExceptionType.connectionError,
      );

      final exception = ApiException.fromDioException(dioException);
      expect(exception, isA<NetworkException>());
    });

    test('Convertit HTTP 400 en BadRequestException', () {
      final dioException = DioException(
        requestOptions: dummyRequestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: dummyRequestOptions,
          statusCode: 400,
          data: {'detail': 'Requête invalide'},
        ),
      );

      final exception = ApiException.fromDioException(dioException);
      expect(exception, isA<BadRequestException>());
      expect(exception.message, equals('Requête invalide'));
      expect(exception.statusCode, equals(400));
    });

    test('Convertit HTTP 401 en UnauthorizedException', () {
      final dioException = DioException(
        requestOptions: dummyRequestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: dummyRequestOptions,
          statusCode: 401,
          data: {'detail': 'Identifiants incorrects'},
        ),
      );

      final exception = ApiException.fromDioException(dioException);
      expect(exception, isA<UnauthorizedException>());
      expect(exception.message, equals('Identifiants incorrects'));
      expect(exception.statusCode, equals(401));
    });

    test('Convertit HTTP 422 Pydantic en ValidationException avec liste d\'erreurs', () {
      final dioException = DioException(
        requestOptions: dummyRequestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: dummyRequestOptions,
          statusCode: 422,
          data: {
            'detail': [
              {
                'loc': ['body', 'telephone'],
                'msg': 'Numéro invalide',
                'type': 'value_error',
              },
            ],
          },
        ),
      );

      final exception = ApiException.fromDioException(dioException);
      expect(exception, isA<ValidationException>());
      final valException = exception as ValidationException;
      expect(valException.errors.length, equals(1));
      expect(valException.firstFieldError, equals('telephone: Numéro invalide'));
      expect(valException.toString(), equals('ApiException(status: 422, message: telephone: Numéro invalide)'));
    });

    test('Convertit HTTP 429 en RateLimitException avec retry_after', () {
      final dioException = DioException(
        requestOptions: dummyRequestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: dummyRequestOptions,
          statusCode: 429,
          data: {
            'detail': 'Trop de requêtes',
            'retry_after': 30,
          },
        ),
      );

      final exception = ApiException.fromDioException(dioException);
      expect(exception, isA<RateLimitException>());
      final rateLimit = exception as RateLimitException;
      expect(rateLimit.retryAfterSeconds, equals(30));
    });

    test('Convertit HTTP 500 en ServerException', () {
      final dioException = DioException(
        requestOptions: dummyRequestOptions,
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: dummyRequestOptions,
          statusCode: 500,
          data: {'detail': 'Erreur interne'},
        ),
      );

      final exception = ApiException.fromDioException(dioException);
      expect(exception, isA<ServerException>());
      expect(exception.statusCode, equals(500));
    });

    test('Convertit cancel en RequestCancelledException', () {
      final dioException = DioException(
        requestOptions: dummyRequestOptions,
        type: DioExceptionType.cancel,
      );

      final exception = ApiException.fromDioException(dioException);
      expect(exception, isA<RequestCancelledException>());
    });
  });
}
