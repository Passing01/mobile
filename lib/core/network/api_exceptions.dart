import 'package:dio/dio.dart';

/// Exception générique de l'API QvGestion
abstract class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final dynamic details;

  const ApiException({
    required this.message,
    this.statusCode,
    this.details,
  });

  @override
  String toString() => 'ApiException(status: $statusCode, message: $message)';

  /// Méthode d'usine pour convertir une DioException en exception typée
  factory ApiException.fromDioException(DioException dioException) {
    switch (dioException.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return const NetworkTimeoutException(
          message: 'Délai de connexion dépassé. Vérifiez votre connexion Internet.',
        );

      case DioExceptionType.connectionError:
        return const NetworkException(
          message: 'Impossible de joindre le serveur. Connexion Internet instable ou indisponible.',
        );

      case DioExceptionType.badResponse:
        final response = dioException.response;
        final statusCode = response?.statusCode;
        final data = response?.data;

        String message = 'Une erreur est survenue lors de la communication avec le serveur.';
        dynamic details;

        if (data is Map<String, dynamic>) {
          if (data.containsKey('detail')) {
            final detail = data['detail'];
            if (detail is String) {
              message = detail;
            } else if (detail is List) {
              // Format de validation Pydantic FastAPI
              return ValidationException(
                message: 'Erreur de validation des données.',
                statusCode: statusCode,
                errors: List<Map<String, dynamic>>.from(
                  detail.whereType<Map<String, dynamic>>(),
                ),
              );
            }
          } else if (data.containsKey('message') && data['message'] is String) {
            message = data['message'];
          }
          details = data;
        }

        switch (statusCode) {
          case 400:
            return BadRequestException(message: message, details: details);
          case 401:
            return UnauthorizedException(message: message, details: details);
          case 403:
            return ForbiddenException(message: message, details: details);
          case 404:
            return NotFoundException(message: message, details: details);
          case 422:
            return ValidationException(
              message: message,
              statusCode: 422,
              errors: const [],
              details: details,
            );
          case 429:
            int? retryAfter;
            if (data is Map<String, dynamic> && data['retry_after'] != null) {
              retryAfter = int.tryParse(data['retry_after'].toString());
            }
            final headerRetry = response?.headers.value('retry-after');
            if (headerRetry != null) {
              retryAfter = int.tryParse(headerRetry) ?? retryAfter;
            }
            return RateLimitException(
              message: message,
              retryAfterSeconds: retryAfter,
              details: details,
            );
          case 500:
          case 502:
          case 503:
          case 504:
            return ServerException(
              message: 'Erreur interne du serveur QvGestion ($statusCode).',
              statusCode: statusCode,
              details: details,
            );
          default:
            return ServerException(
              message: message,
              statusCode: statusCode,
              details: details,
            );
        }

      case DioExceptionType.cancel:
        return const RequestCancelledException(
          message: 'La requête a été annulée.',
        );

      case DioExceptionType.badCertificate:
        return const SecurityException(
          message: 'Certificat de sécurité SSL invalide ou suspect.',
        );

      case DioExceptionType.unknown:
      default:
        return UnknownApiException(
          message: dioException.message ?? 'Une erreur inattendue est survenue.',
        );
    }
  }
}

class NetworkException extends ApiException {
  const NetworkException({required super.message, super.statusCode, super.details});
}

class NetworkTimeoutException extends NetworkException {
  const NetworkTimeoutException({required super.message, super.statusCode, super.details});
}

class BadRequestException extends ApiException {
  const BadRequestException({required super.message, super.details})
      : super(statusCode: 400);
}

class UnauthorizedException extends ApiException {
  const UnauthorizedException({required super.message, super.details})
      : super(statusCode: 401);
}

class ForbiddenException extends ApiException {
  const ForbiddenException({required super.message, super.details})
      : super(statusCode: 403);
}

class NotFoundException extends ApiException {
  const NotFoundException({required super.message, super.details})
      : super(statusCode: 404);
}

class ValidationException extends ApiException {
  final List<Map<String, dynamic>> errors;

  const ValidationException({
    required super.message,
    super.statusCode = 422,
    this.errors = const [],
    super.details,
  });

  /// Extrait le premier message d'erreur de champ lisible
  String get firstFieldError {
    if (errors.isNotEmpty) {
      final first = errors.first;
      final msg = first['msg'] as String?;
      final loc = first['loc'] as List?;
      final field = loc != null && loc.isNotEmpty ? loc.last.toString() : '';
      if (msg != null && field.isNotEmpty) {
        return '$field: $msg';
      } else if (msg != null) {
        return msg;
      }
    }
    return message;
  }

  @override
  String toString() {
    if (errors.isNotEmpty) {
      return 'ApiException(status: $statusCode, message: $firstFieldError)';
    }
    return 'ApiException(status: $statusCode, message: $message)';
  }
}

class RateLimitException extends ApiException {
  final int? retryAfterSeconds;

  const RateLimitException({
    required super.message,
    this.retryAfterSeconds,
    super.details,
  }) : super(statusCode: 429);
}

class ServerException extends ApiException {
  const ServerException({
    required super.message,
    super.statusCode,
    super.details,
  });
}

class SecurityException extends ApiException {
  const SecurityException({required super.message, super.statusCode, super.details});
}

class RequestCancelledException extends ApiException {
  const RequestCancelledException({required super.message, super.statusCode, super.details});
}

class UnknownApiException extends ApiException {
  const UnknownApiException({required super.message, super.statusCode, super.details});
}
