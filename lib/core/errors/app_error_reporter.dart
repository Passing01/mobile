import 'package:flutter/material.dart';
import 'package:qvgestion_mobile/core/debug/debug_info.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';

/// Gestionnaire global de signalement d'erreur visible à l'écran (Règle 4 FASO NAV)
/// "Aucun repli silencieux : une erreur d'API, de GPS ou de calcul s'affiche à l'écran
/// dans un bandeau et dans le journal. L'app n'invente jamais un résultat à la place."
class AppErrorReporter {
  static final GlobalKey<ScaffoldMessengerState> messengerKey =
      GlobalKey<ScaffoldMessengerState>();

  /// Signale une erreur de manière visible (bandeau) et l'inscrit au journal et à DebugInfo
  static void reportError(
    String userMessage, {
    dynamic error,
    StackTrace? stackTrace,
    String tag = 'Erreur',
  }) {
    // 1. Inscrire dans le journal interne
    AppLogger.error(
      userMessage,
      error: error,
      stackTrace: stackTrace,
      tag: tag,
    );

    // 2. Mettre à jour la télémétrie de debug
    final fullError = error != null ? '$userMessage: $error' : userMessage;
    DebugInfo.instance.setLastApiError('[$tag] $fullError');

    // 3. Afficher un bandeau rouge visible à l'écran
    final messenger = messengerKey.currentState;
    if (messenger != null) {
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(Icons.error_outline_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '[$tag] $userMessage',
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                        fontSize: 13,
                      ),
                    ),
                    if (error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          '$error',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFFFFD2D2),
                            fontSize: 11,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFDC2626), // Rouge alerte
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          action: SnackBarAction(
            label: 'OK',
            textColor: Colors.white,
            onPressed: () {
              messenger.hideCurrentSnackBar();
            },
          ),
        ),
      );
    }
  }

  /// Signale un avertissement visible
  static void reportWarning(
    String message, {
    String tag = 'Attention',
  }) {
    AppLogger.warning(message, tag: tag);

    final messenger = messengerKey.currentState;
    if (messenger != null) {
      messenger.removeCurrentSnackBar();
      messenger.showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 22),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '[$tag] $message',
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                ),
              ),
            ],
          ),
          backgroundColor: const Color(0xFFD97706), // Ambre alerte
          behavior: SnackBarBehavior.floating,
          margin: const EdgeInsets.all(12),
          duration: const Duration(seconds: 4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      );
    }
  }
}
