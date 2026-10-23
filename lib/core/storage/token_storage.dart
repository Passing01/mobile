import 'dart:convert';
import 'package:qvgestion_mobile/core/config/app_constants.dart';
import 'package:qvgestion_mobile/core/storage/secure_storage_service.dart';

/// Gestionnaire sécurisé des jetons JWT (Access Token & Refresh Token)
class TokenStorage {
  final ISecureStorage storage;

  TokenStorage({required this.storage});

  /// Sauvegarde les deux jetons après connexion ou inscription
  Future<void> saveTokens({
    required String accessToken,
    required String refreshToken,
  }) async {
    await Future.wait([
      storage.write(key: AppConstants.keyAccessToken, value: accessToken),
      storage.write(key: AppConstants.keyRefreshToken, value: refreshToken),
    ]);
  }

  /// Sauvegarde uniquement le nouvel access token après un rafraîchissement
  Future<void> saveAccessToken(String accessToken) async {
    await storage.write(key: AppConstants.keyAccessToken, value: accessToken);
  }

  /// Récupère l'access token actuel
  Future<String?> getAccessToken() async {
    return await storage.read(key: AppConstants.keyAccessToken);
  }

  /// Récupère le refresh token actuel
  Future<String?> getRefreshToken() async {
    return await storage.read(key: AppConstants.keyRefreshToken);
  }

  /// Vérifie si un access token est stocké
  Future<bool> hasAccessToken() async {
    final token = await getAccessToken();
    return token != null && token.isNotEmpty;
  }

  /// Vérifie si l'access token est expiré en analysant le payload JWT
  Future<bool> isAccessTokenExpired({Duration buffer = const Duration(seconds: 30)}) async {
    final token = await getAccessToken();
    if (token == null || token.isEmpty) return true;

    return isJwtExpired(token, buffer: buffer);
  }

  /// Détermine si un JWT est expiré en analysant son champ 'exp'
  static bool isJwtExpired(String token, {Duration buffer = Duration.zero}) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return true;

      final normalizedPayload = base64Url.normalize(parts[1]);
      final payloadString = utf8.decode(base64Url.decode(normalizedPayload));
      final Map<String, dynamic> payload = jsonDecode(payloadString);

      if (!payload.containsKey('exp')) return false;

      final expSeconds = payload['exp'] as int;
      final expDate = DateTime.fromMillisecondsSinceEpoch(expSeconds * 1000);
      final nowWithBuffer = DateTime.now().add(buffer);

      return expDate.isBefore(nowWithBuffer);
    } catch (_) {
      return true;
    }
  }

  /// Efface tous les jetons (déconnexion complète)
  Future<void> clearTokens() async {
    await Future.wait([
      storage.delete(key: AppConstants.keyAccessToken),
      storage.delete(key: AppConstants.keyRefreshToken),
    ]);
  }
}
