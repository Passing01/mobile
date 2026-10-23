import 'package:dio/dio.dart';
import 'package:qvgestion_mobile/core/config/env_config.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/storage/token_storage.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';

/// Intercepteur d'authentification Dio avec gestion de file d'attente (QueuedInterceptor)
/// pour gérer le renouvellement transparent du jeton JWT sans race conditions.
class AuthInterceptor extends QueuedInterceptor {
  final TokenStorage tokenStorage;
  final Dio dio;
  final Dio _refreshDio;
  final void Function()? onTokenExpired;

  AuthInterceptor({
    required this.tokenStorage,
    required this.dio,
    Dio? refreshDio,
    this.onTokenExpired,
  })  : _refreshDio = refreshDio ??
            Dio(
              BaseOptions(
                baseUrl: EnvConfig.apiBaseUrl,
                connectTimeout: EnvConfig.connectTimeout,
                receiveTimeout: EnvConfig.receiveTimeout,
                headers: {
                  'Accept': 'application/json',
                  'Content-Type': 'application/json',
                },
              ),
            );

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    // Ajout de la compression GZip pour économie de data au Burkina Faso
    options.headers['Accept-Encoding'] = 'gzip';
    options.headers['Accept'] = 'application/json';

    // Injection automatique du token Bearer si disponible
    final token = await tokenStorage.getAccessToken();
    if (token != null && token.isNotEmpty) {
      options.headers['Authorization'] = 'Bearer $token';
    }

    return handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;

    // Éviter les boucles infinies sur les routes d'authentification
    final isAuthRoute = path.contains(ApiEndpoints.login) ||
        path.contains(ApiEndpoints.register) ||
        path.contains(ApiEndpoints.refresh);

    if (statusCode == 401 && !isAuthRoute) {
      AppLogger.w('Jeton expiré (401) sur $path. Tentative de renouvellement...');
      final refreshToken = await tokenStorage.getRefreshToken();

      if (refreshToken == null || refreshToken.isEmpty) {
        AppLogger.w('Aucun Refresh Token disponible. Déconnexion requise.');
        await tokenStorage.clearTokens();
        onTokenExpired?.call();
        return handler.next(err);
      }

      try {
        final refreshResponse = await _refreshDio.post(
          ApiEndpoints.refresh,
          data: {'refresh_token': refreshToken},
        );

        if (refreshResponse.statusCode == 200 && refreshResponse.data != null) {
          final data = refreshResponse.data as Map<String, dynamic>;
          final newAccessToken = data['access_token'] as String;
          final newRefreshToken = (data['refresh_token'] as String?) ?? refreshToken;

          await tokenStorage.saveTokens(
            accessToken: newAccessToken,
            refreshToken: newRefreshToken,
          );

          AppLogger.i('Jeton rafraîchi avec succès. Rejeu de la requête initiale.');

          // Mettre à jour l'en-tête de la requête initiale
          err.requestOptions.headers['Authorization'] = 'Bearer $newAccessToken';

          // Rejouer la requête d'origine avec le nouveau jeton
          final retryResponse = await dio.fetch(err.requestOptions);
          return handler.resolve(retryResponse);
        }
      } catch (refreshError) {
        AppLogger.e('Échec du rafraîchissement du jeton: $refreshError');
        await tokenStorage.clearTokens();
        onTokenExpired?.call();
      }
    }

    return handler.next(err);
  }
}
