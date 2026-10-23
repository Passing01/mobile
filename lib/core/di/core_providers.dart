import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/config/env_config.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/storage/secure_storage_service.dart';
import 'package:qvgestion_mobile/core/storage/token_storage.dart';

/// Fournisseur du stockage sécurisé
final secureStorageProvider = Provider<ISecureStorage>((ref) {
  return SecureStorageService();
});

/// Fournisseur de la gestion des jetons
final tokenStorageProvider = Provider<TokenStorage>((ref) {
  final storage = ref.watch(secureStorageProvider);
  return TokenStorage(storage: storage);
});

/// Fournisseur du client HTTP API
final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  return ApiClient(
    tokenStorage: tokenStorage,
    onTokenExpired: () {
      // Déclencheur global de déconnexion / redirection vers l'écran de login
    },
  );
});

/// Fournisseur d'environnement
final environmentProvider = Provider<AppEnvironment>((ref) {
  return EnvConfig.environment;
});
