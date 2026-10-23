class AppConstants {
  // Informations de l'application
  static const String appName = 'QVGestion Mobile';
  static const String appVersion = '1.0.0';

  // Langues supportées par QvGestion
  static const String langFrench = 'fr';
  static const String langMoore = 'mos';
  static const String langDioula = 'diu';
  static const List<String> supportedLanguages = [
    langFrench,
    langMoore,
    langDioula,
  ];
  static const String defaultLanguage = langFrench;

  // Clés de stockage sécurisé / préférences
  static const String keyAccessToken = 'access_token';
  static const String keyRefreshToken = 'refresh_token';
  static const String keyUserProfile = 'user_profile';
  static const String keyPreferredLanguage = 'preferred_language';
  static const String keyOfflineModeEnabled = 'offline_mode_enabled';

  // Limites géographiques du Burkina Faso (WGS84 EPSG:4326)
  static const double burkinaMinLatitude = 9.0;
  static const double burkinaMaxLatitude = 15.5;
  static const double burkinaMinLongitude = -5.5;
  static const double burkinaMaxLongitude = 2.5;

  // Coordonnées de référence
  // Ouagadougou (Centre)
  static const double ouagaCenterLatitude = 12.3685;
  static const double ouagaCenterLongitude = -1.5271;

  // Bobo-Dioulasso (Hauts-Bassins)
  static const double boboCenterLatitude = 11.1772;
  static const double boboCenterLongitude = -4.2979;

  // Koudougou (Centre-Ouest)
  static const double koudougouCenterLatitude = 12.2526;
  static const double koudougouCenterLongitude = -2.3627;

  // Préfixes téléphoniques mobiles au Burkina Faso
  static const String burkinaCountryCode = '+226';
}
