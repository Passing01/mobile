import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/config/env_config.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/services/location_link_parser.dart';
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

/// Contrôleur global notifiant l'application lorsqu'une session / JWT a expiré (HTTP 401 irrécupérable)
final sessionExpiredControllerProvider = Provider<StreamController<void>>((ref) {
  final controller = StreamController<void>.broadcast();
  ref.onDispose(controller.close);
  return controller;
});

/// Flux global d'expiration de session écouté par AuthNotifier
final sessionExpiredStreamProvider = StreamProvider<void>((ref) {
  return ref.watch(sessionExpiredControllerProvider).stream;
});

/// Fournisseur du client HTTP API
final apiClientProvider = Provider<ApiClient>((ref) {
  final tokenStorage = ref.watch(tokenStorageProvider);
  final sessionExpiredController = ref.watch(sessionExpiredControllerProvider);
  return ApiClient(
    tokenStorage: tokenStorage,
    onTokenExpired: () {
      if (!sessionExpiredController.isClosed) {
        sessionExpiredController.add(null);
      }
    },
  );
});

/// Fournisseur d'environnement
final environmentProvider = Provider<AppEnvironment>((ref) {
  return EnvConfig.environment;
});

/// Service d'écoute des liens et partages de localisation entrants (WhatsApp, Web, geo:)
final locationIntentServiceProvider = Provider<LocationIntentService>((ref) {
  final service = LocationIntentService();
  ref.onDispose(service.dispose);
  return service;
});
