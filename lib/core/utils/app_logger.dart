import 'package:flutter/foundation.dart';
import 'package:logger/logger.dart';

enum LogLevel {
  info,
  warning,
  error,
}

class LogEntry {
  final DateTime timestamp;
  final LogLevel level;
  final String tag;
  final String message;
  final dynamic error;
  final StackTrace? stackTrace;

  LogEntry({
    required this.timestamp,
    required this.level,
    required this.tag,
    required this.message,
    this.error,
    this.stackTrace,
  });

  String get formattedTime {
    final h = timestamp.hour.toString().padLeft(2, '0');
    final m = timestamp.minute.toString().padLeft(2, '0');
    final s = timestamp.second.toString().padLeft(2, '0');
    final ms = timestamp.millisecond.toString().padLeft(3, '0');
    return '$h:$m:$s.$ms';
  }

  String get levelLabel {
    switch (level) {
      case LogLevel.info:
        return 'INFO';
      case LogLevel.warning:
        return 'WARN';
      case LogLevel.error:
        return 'ERROR';
    }
  }

  @override
  String toString() {
    final buffer = StringBuffer();
    buffer.write('[${timestamp.toIso8601String()}] [$levelLabel] [$tag] $message');
    if (error != null) {
      buffer.write(' | Erreur: $error');
    }
    if (stackTrace != null) {
      buffer.write('\n$stackTrace');
    }
    return buffer.toString();
  }
}

/// Système de journalisation centralisé et exportable pour FASO NAV (Étape 0)
class AppLogger {
  static const int maxEntries = 1000;
  static final List<LogEntry> _entries = [];
  static final ValueNotifier<List<LogEntry>> entriesNotifier =
      ValueNotifier<List<LogEntry>>([]);

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

  static List<LogEntry> get entries => List.unmodifiable(_entries);

  // Méthodes compatibles avec l'existant
  static void d(String message, [dynamic error, StackTrace? stackTrace]) {
    if (!kReleaseMode) {
      final sanitized = _sanitize(message);
      _logger.d(sanitized, error: error, stackTrace: stackTrace);
      _addEntry(LogEntry(
        timestamp: DateTime.now(),
        level: LogLevel.info,
        tag: 'DEBUG',
        message: sanitized,
        error: error,
        stackTrace: stackTrace,
      ));
    }
  }

  static void i(String message, [dynamic error, StackTrace? stackTrace]) {
    final sanitized = _sanitize(message);
    _logger.i(sanitized, error: error, stackTrace: stackTrace);
    _addEntry(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.info,
      tag: 'INFO',
      message: sanitized,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  static void w(String message, [dynamic error, StackTrace? stackTrace]) {
    final sanitized = _sanitize(message);
    _logger.w(sanitized, error: error, stackTrace: stackTrace);
    _addEntry(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.warning,
      tag: 'WARN',
      message: sanitized,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  static void e(String message, [dynamic error, StackTrace? stackTrace]) {
    final sanitized = _sanitize(message);
    _logger.e(sanitized, error: error, stackTrace: stackTrace);
    _addEntry(LogEntry(
      timestamp: DateTime.now(),
      level: LogLevel.error,
      tag: 'ERROR',
      message: sanitized,
      error: error,
      stackTrace: stackTrace,
    ));
  }

  // Méthodes nommées explicites
  static void info(String message, {String tag = 'FASO'}) {
    i('[$tag] $message');
  }

  static void warning(String message, {String tag = 'FASO'}) {
    w('[$tag] $message');
  }

  static void error(
    String message, {
    dynamic error,
    StackTrace? stackTrace,
    String tag = 'FASO',
  }) {
    e('[$tag] $message', error, stackTrace);
  }

  static void _addEntry(LogEntry entry) {
    if (_entries.length >= maxEntries) {
      _entries.removeAt(0);
    }
    _entries.add(entry);
    entriesNotifier.value = List.unmodifiable(_entries);
  }

  /// Exporte la totalité du journal sous forme de texte pour les validations et preuves
  static String exportLogs() {
    if (_entries.isEmpty) {
      return '--- Journal FASO NAV vide ---';
    }
    final buffer = StringBuffer();
    buffer.writeln('=== JOURNAL D\'EXÉCUTION FASO NAV ===');
    buffer.writeln('Date d\'export: ${DateTime.now().toIso8601String()}');
    buffer.writeln('Nombre d\'entrées: ${_entries.length}');
    buffer.writeln('--------------------------------------------------');
    for (final entry in _entries) {
      buffer.writeln(entry.toString());
    }
    buffer.writeln('=== FIN DU JOURNAL ===');
    return buffer.toString();
  }

  static void clear() {
    _entries.clear();
    entriesNotifier.value = [];
  }

  /// Masque les données sensibles (tokens JWT, mots de passe)
  static String _sanitize(String message) {
    var sanitized = message;
    sanitized = sanitized.replaceAll(
      RegExp(r'Bearer\s+[A-Za-z0-9\-._~+/]+=*', caseSensitive: false),
      'Bearer [REDACTED_TOKEN]',
    );
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
