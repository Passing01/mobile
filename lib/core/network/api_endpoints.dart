class ApiEndpoints {
  // --- Authentification ---
  static const String register = '/auth/register';
  static const String login = '/auth/login';
  static const String refresh = '/auth/refresh';

  // --- Profil Utilisateur ---
  static const String userMe = '/users/me';

  // --- Catégories & Lieux (POI) ---
  static const String categories = '/categories/';
  static const String places = '/places/';
  static const String placesNearby = '/places/nearby';
  static const String placesSearch = '/places/search';
  static String placeDetail(int placeId) => '/places/$placeId';
  static String placeFavorite(int placeId) => '/places/$placeId/favorite';
  static const String userFavorites = '/places/favorites';
  static String removeFavorite(int placeId) => '/places/$placeId/favorite';

  // --- Itinéraires & Navigation ---
  static const String routeModes = '/routes/modes';
  static const String routeCalculate = '/routes/calculate';
  static String routeVoiceStep(int routeId, int stepIndex) =>
      '/routes/$routeId/voice/$stepIndex';

  // --- Guidage Vocal & Repères Locaux ---
  static const String guidanceDictionary = '/guidance/dictionary';
  static const String guidanceLandmarks = '/guidance/landmarks';
  static const String guidanceEnrichRoute = '/guidance/enrich-route';
  static String guidanceAudio(String soundId) => '/guidance/audio/$soundId.wav';

  // --- Signalements d'Incidents ---
  static const String reports = '/reports/';
  static const String reportsActive = '/reports/active';
  static const String reportsTypes = '/reports/types';
  static String reportDetail(int reportId) => '/reports/$reportId';
  static String reportVote(int reportId) => '/reports/$reportId/vote';
  static String reportStatus(int reportId) => '/reports/$reportId/status';

  // --- Télémétrie, Trafic & Partage de Trajet ---
  static const String telemetry = '/traffic/telemetry';
  static const String trafficCongestion = '/traffic/congestion';
  static const String trackingShare = '/traffic/tracking/share';
  static String trackingDetail(String token) => '/traffic/tracking/$token';
  static String trackingUpdate(String token) => '/traffic/tracking/$token/update';
  static String trackingStop(String token) => '/traffic/tracking/$token';

  // --- Mode Hors-Ligne & PMTiles ---
  static const String offlinePacks = '/offline/packs';
  static String offlinePackDetail(String packId) => '/offline/packs/$packId';
  static String offlinePackDownload(String packId) => '/offline/packs/$packId/download';
  static String offlinePackPois(String packId) => '/offline/packs/$packId/pois';
  static const String offlineCheckUpdates = '/offline/check-updates';
  static const String offlineMyPacks = '/offline/my-packs';

  // --- Notifications & Alertes ---
  static const String notificationsMy = '/notifications/my-notifications';
  static String notificationRead(int id) => '/notifications/$id/read';
  static const String notificationsDevices = '/notifications/devices';
  static const String notificationsGeoAlert = '/notifications/geo-alert';

  // --- Météo Locale ---
  static const String weatherCurrent = '/weather/current';
  static const String weatherForecast = '/weather/forecast';

  // --- Back-Office & Administration ---
  static const String adminDashboard = '/admin/dashboard';
  static const String adminPendingPlaces = '/admin/pending-places';
  static String adminModeratePlace(int placeId) => '/admin/places/$placeId/moderate';
  static const String adminRoadFeatures = '/guidance/road-features';
}
