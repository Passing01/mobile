import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

/// Système de journalisation sécurisé pour QvGestion Mobile.
/// En production ou release, les logs verbeux sont désactivés pour protéger les performances et la vie privée.
class AppLogger {
  static final Logger _logger = Logger(
    printer: PrettyPrinter(
      methodCount: 1,
      errorMethodCount: 5,
      lineLength: 80,
      colors: true,
      printEmojis: true,
      dateTimeFormat: DateTimeFormat.onlyTimeAndSinceStart,
    ),
    level: kReleaseMode ? Level.warning : Level.debug,
  );

  static void d(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!kReleaseMode) {
      _logger.d(_sanitize(message), error: error, stackTrace: stackTrace);
    }
  }

  static void i(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.i(_sanitize(message), error: error, stackTrace: stackTrace);
  }

  static void w(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.w(_sanitize(message), error: error, stackTrace: stackTrace);
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    _logger.e(_sanitize(message), error: error, stackTrace: stackTrace);
  }

  /// Masque les données sensibles (tokens JWT, mots de passe) avant affichage dans la console
  static String _sanitize(String message) {
    var sanitized = message;
    // Masquer les jetons Bearer
    sanitized = sanitized.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
      'Bearer [REDACTED_TOKEN]',
    );
    // Masquer les clés de mot de passe JSON
    sanitized = sanitized.replaceAll(
      RegExp(r'"mot_de_passe"\s*:\s*"[^"]*"', caseSensitive: false),
      '"mot_de_passe": "[REDACTED_PASSWORD]"',
    );
    sanitized = sanitized.replaceAll(
      RegExp(r'"password"\s*:\s*"[^"]*"', caseSensitive: false),
      '"password": "[REDACTED_PASSWORD]"',
    );
    return sanitized;
  }
}
