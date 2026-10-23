/// Configuration globale de l'application et gestion du mode test (Étape 0)
class AppConfig {
  /// Mode test activable via la variable d'environnement Dart :
  /// flutter run --dart-define=TEST_MODE=true
  /// Par défaut : false (Désactivé en production - Règle non négociable 5)
  static const bool testMode = bool.fromEnvironment('TEST_MODE', defaultValue: false);

  /// URL de l'API de test (si non spécifiée, utilise le port 8001 en local)
  static const String testApiUrl = String.fromEnvironment(
    'TEST_API_URL',
    defaultValue: '',
  );
}
