import 'dart:convert';
import 'package:qvgestion_mobile/core/config/app_constants.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/storage/secure_storage_service.dart';
import 'package:qvgestion_mobile/core/storage/token_storage.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/auth/data/models/auth_response_model.dart';
import 'package:qvgestion_mobile/features/auth/data/models/user_model.dart';

abstract class IAuthRepository {
  Future<UserModel> login({required String identifier, required String password});
  Future<UserModel> register({
    required String nom,
    required String telephone,
    String? email,
    required String password,
    String languePreferee = 'mos',
  });
  Future<UserModel?> getCurrentUser();
  Future<UserModel> updateProfile({
    String? nom,
    String? telephone,
    String? languePreferee,
  });
  Future<void> logout();
  Future<bool> isAuthenticated();
}

class AuthRepository implements IAuthRepository {
  final ApiClient apiClient;
  final TokenStorage tokenStorage;
  final ISecureStorage secureStorage;

  AuthRepository({
    required this.apiClient,
    required this.tokenStorage,
    required this.secureStorage,
  });

  @override
  Future<UserModel> login({
    required String identifier,
    required String password,
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.login,
      data: {
        'identifiant': identifier,
        'mot_de_passe': password,
      },
    );

    final authResponse = AuthResponseModel.fromJson(response.data as Map<String, dynamic>);

    await tokenStorage.saveTokens(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
    );

    if (authResponse.user != null) {
      await _cacheUser(authResponse.user!);
      return authResponse.user!;
    }

    // Si le endpoint ne retourne pas l'objet user directement, on va le chercher via /users/me
    return await getCurrentUser() ??
        UserModel(
          id: 0,
          nom: identifier,
          telephone: identifier,
        );
  }

  @override
  Future<UserModel> register({
    required String nom,
    required String telephone,
    String? email,
    required String password,
    String languePreferee = 'mos',
  }) async {
    final response = await apiClient.post(
      ApiEndpoints.register,
      data: {
        'nom': nom,
        'telephone': telephone,
        if (email != null && email.isNotEmpty) 'email': email,
        'mot_de_passe': password,
        'langue_preferee': languePreferee,
      },
    );

    final authResponse = AuthResponseModel.fromJson(response.data as Map<String, dynamic>);

    await tokenStorage.saveTokens(
      accessToken: authResponse.accessToken,
      refreshToken: authResponse.refreshToken,
    );

    if (authResponse.user != null) {
      await _cacheUser(authResponse.user!);
      return authResponse.user!;
    }

    return await getCurrentUser() ??
        UserModel(
          id: 0,
          nom: nom,
          telephone: telephone,
          email: email,
          languePreferee: languePreferee,
        );
  }

  @override
  Future<UserModel?> getCurrentUser() async {
    try {
      final response = await apiClient.get(ApiEndpoints.userMe);
      final user = UserModel.fromJson(response.data as Map<String, dynamic>);
      await _cacheUser(user);
      return user;
    } catch (e) {
      AppLogger.w('Impossible de récupérer le profil distant, tentative depuis le cache: $e');
      return await _getCachedUser();
    }
  }

  @override
  Future<UserModel> updateProfile({
    String? nom,
    String? telephone,
    String? languePreferee,
  }) async {
    final body = <String, dynamic>{};
    if (nom != null) body['nom'] = nom;
    if (telephone != null) body['telephone'] = telephone;
    if (languePreferee != null) body['langue_preferee'] = languePreferee;

    final response = await apiClient.put(
      ApiEndpoints.userMe,
      data: body,
    );

    final updatedUser = UserModel.fromJson(response.data as Map<String, dynamic>);
    await _cacheUser(updatedUser);
    return updatedUser;
  }

  @override
  Future<void> logout() async {
    await Future.wait([
      tokenStorage.clearTokens(),
      secureStorage.delete(key: AppConstants.keyUserProfile),
    ]);
  }

  @override
  Future<bool> isAuthenticated() async {
    return await tokenStorage.hasAccessToken();
  }

  Future<void> _cacheUser(UserModel user) async {
    final rawJson = jsonEncode(user.toJson());
    await secureStorage.write(key: AppConstants.keyUserProfile, value: rawJson);
  }

  Future<UserModel?> _getCachedUser() async {
    try {
      final raw = await secureStorage.read(key: AppConstants.keyUserProfile);
      if (raw != null && raw.isNotEmpty) {
        return UserModel.fromJson(jsonDecode(raw) as Map<String, dynamic>);
      }
    } catch (e) {
      AppLogger.w('Échec lecture cache utilisateur: $e');
    }
    return null;
  }
}
