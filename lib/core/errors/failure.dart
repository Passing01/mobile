import 'package:equatable/equatable.dart';

/// Classe de base abstraite représentant un échec métier ou technique
abstract class Failure extends Equatable {
  final String message;
  final int? statusCode;

  const Failure({required this.message, this.statusCode});

  @override
  List<Object?> get props => [message, statusCode];
}

class ServerFailure extends Failure {
  const ServerFailure({required super.message, super.statusCode});
}

class NetworkFailure extends Failure {
  const NetworkFailure({
    super.message = 'Vérifiez votre connexion Internet et réessayez.',
    super.statusCode,
  });
}

class AuthFailure extends Failure {
  const AuthFailure({required super.message, super.statusCode = 401});
}

class ValidationFailure extends Failure {
  final List<String> fieldErrors;

  const ValidationFailure({
    required super.message,
    this.fieldErrors = const [],
    super.statusCode = 422,
  });

  @override
  List<Object?> get props => [message, statusCode, fieldErrors];
}

class CacheFailure extends Failure {
  const CacheFailure({
    super.message = 'Erreur lors de la lecture ou de l’écriture locale.',
    super.statusCode,
  });
}

class RateLimitFailure extends Failure {
  final int? retryAfterSeconds;

  const RateLimitFailure({
    required super.message,
    this.retryAfterSeconds,
    super.statusCode = 429,
  });

  @override
  List<Object?> get props => [message, statusCode, retryAfterSeconds];
}
