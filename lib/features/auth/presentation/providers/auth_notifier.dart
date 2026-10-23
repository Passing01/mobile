import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
import 'package:qvgestion_mobile/core/errors/app_error_reporter.dart';
import 'package:qvgestion_mobile/core/network/api_exceptions.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:qvgestion_mobile/features/auth/presentation/providers/auth_state.dart';

/// Provider du repository d'authentification
final authRepositoryProvider = Provider<IAuthRepository>((ref) {
  final apiClient = ref.watch(apiClientProvider);
  final tokenStorage = ref.watch(tokenStorageProvider);
  final secureStorage = ref.watch(secureStorageProvider);

  return AuthRepository(
    apiClient: apiClient,
    tokenStorage: tokenStorage,
    secureStorage: secureStorage,
  );
});

/// Notifier moderne Riverpod 3 gérant l'état global de connexion de l'utilisateur
class AuthNotifier extends Notifier<AuthState> {
  IAuthRepository get _authRepository => ref.read(authRepositoryProvider);

  @override
  AuthState build() {
    return const AuthState(status: AuthStatus.unauthenticated);
  }

  /// Vérifie si l'utilisateur possède déjà une session active au démarrage
  Future<void> checkAuthStatus() async {
    state = state.copyWith(status: AuthStatus.loading);
    try {
      final isAuth = await _authRepository.isAuthenticated();
      if (!isAuth) {
        state = state.copyWith(status: AuthStatus.unauthenticated);
        return;
      }

      final user = await _authRepository.getCurrentUser();
      if (user != null) {
        state = state.copyWith(
          status: AuthStatus.authenticated,
          user: user,
          errorMessage: null,
        );
      } else {
        state = state.copyWith(status: AuthStatus.unauthenticated);
      }
    } catch (_) {
      state = state.copyWith(status: AuthStatus.unauthenticated);
    }
  }

  /// Connexion par numéro de téléphone ou email
  Future<bool> login({
    required String identifier,
    required String password,
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await _authRepository.login(
        identifier: identifier,
        password: password,
      );

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
      );
      return true;
    } on ApiException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Échec de la connexion. Vérifiez vos identifiants.',
      );
      return false;
    }
  }

  /// Inscription d'un nouvel usager avec préférences linguistiques
  Future<bool> register({
    required String nom,
    required String telephone,
    String? email,
    required String password,
    String languePreferee = 'mos',
  }) async {
    state = state.copyWith(status: AuthStatus.loading, errorMessage: null);
    try {
      final user = await _authRepository.register(
        nom: nom,
        telephone: telephone,
        email: email,
        password: password,
        languePreferee: languePreferee,
      );

      state = state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        errorMessage: null,
      );
      return true;
    } on ValidationException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.firstFieldError,
      );
      return false;
    } on ApiException catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: e.message,
      );
      return false;
    } catch (e) {
      state = state.copyWith(
        status: AuthStatus.error,
        errorMessage: 'Échec de la création du compte. Veuillez réessayer.',
      );
      return false;
    }
  }

  /// Mise à jour de la langue préférée (Mooré, Dioula, Français)
  Future<void> updateLanguage(String languePreferee) async {
    if (state.user == null) return;
    try {
      final updated = await _authRepository.updateProfile(
        languePreferee: languePreferee,
      );
      state = state.copyWith(user: updated);
    } catch (e) {
      AppLogger.w('Impossible de synchroniser la langue avec le serveur: $e');
      AppErrorReporter.reportWarning('Impossible de synchroniser la préférence de langue', tag: 'Profil');
    }
  }

  /// Déconnexion complète
  Future<void> logout() async {
    await _authRepository.logout();
    state = const AuthState(status: AuthStatus.unauthenticated);
  }
}

/// Provider moderne Riverpod 3 d'état d'authentification
final authNotifierProvider = NotifierProvider<AuthNotifier, AuthState>(AuthNotifier.new);
