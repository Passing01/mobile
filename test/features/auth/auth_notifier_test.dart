import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/core/di/core_providers.dart';
import 'package:qvgestion_mobile/core/network/api_exceptions.dart';
import 'package:qvgestion_mobile/features/auth/data/models/user_model.dart';
import 'package:qvgestion_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:qvgestion_mobile/features/auth/presentation/providers/auth_notifier.dart';
import 'package:qvgestion_mobile/features/auth/presentation/providers/auth_state.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockAuthRepository mockRepository;

  const testUser = UserModel(
    id: 14,
    nom: 'Rasmané Ouedraogo',
    telephone: '+22670223344',
    languePreferee: 'mos',
  );

  setUp(() {
    mockRepository = MockAuthRepository();
    when(() => mockRepository.isAuthenticated()).thenAnswer((_) async => false);
  });

  ProviderContainer createContainer() {
    final container = ProviderContainer(
      overrides: [
        authRepositoryProvider.overrideWithValue(mockRepository),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  group('AuthNotifier Tests (Riverpod 3)', () {
    test('Initialise en mode non authentifié si aucun token', () async {
      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      await notifier.checkAuthStatus();

      expect(container.read(authNotifierProvider).status, equals(AuthStatus.unauthenticated));
      expect(container.read(authNotifierProvider).user, isNull);
    });

    test('login réussie met à jour l\'état en Authenticated', () async {
      when(() => mockRepository.login(
            identifier: '+22670223344',
            password: 'Burkina2026!',
          )).thenAnswer((_) async => testUser);

      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      final result = await notifier.login(
        identifier: '+22670223344',
        password: 'Burkina2026!',
      );

      expect(result, isTrue);
      final state = container.read(authNotifierProvider);
      expect(state.status, equals(AuthStatus.authenticated));
      expect(state.user, equals(testUser));
      expect(state.errorMessage, isNull);
    });

    test('login avec erreur 401 met à jour l\'état en Error avec message', () async {
      when(() => mockRepository.login(
            identifier: any(named: 'identifier'),
            password: any(named: 'password'),
          )).thenThrow(
        const UnauthorizedException(
          message: 'Identifiant ou mot de passe incorrect.',
        ),
      );

      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      final result = await notifier.login(
        identifier: '+22670223344',
        password: 'wrong_password',
      );

      expect(result, isFalse);
      final state = container.read(authNotifierProvider);
      expect(state.status, equals(AuthStatus.error));
      expect(state.errorMessage, equals('Identifiant ou mot de passe incorrect.'));
    });

    test('register réussie connecte l\'utilisateur', () async {
      when(() => mockRepository.register(
            nom: 'Rasmané',
            telephone: '+22670223344',
            password: 'Burkina2026!',
            languePreferee: 'diu',
          )).thenAnswer((_) async => testUser.copyWith(languePreferee: 'diu'));

      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      final result = await notifier.register(
        nom: 'Rasmané',
        telephone: '+22670223344',
        password: 'Burkina2026!',
        languePreferee: 'diu',
      );

      expect(result, isTrue);
      final state = container.read(authNotifierProvider);
      expect(state.status, equals(AuthStatus.authenticated));
      expect(state.user?.languePreferee, equals('diu'));
    });

    test('logout réinitialise l\'état à unauthenticated', () async {
      when(() => mockRepository.logout()).thenAnswer((_) async {});

      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      await notifier.logout();

      final state = container.read(authNotifierProvider);
      expect(state.status, equals(AuthStatus.unauthenticated));
      expect(state.user, isNull);
      verify(() => mockRepository.logout()).called(1);
    });

    test('expiration du jeton (sessionExpiredControllerProvider) déconnecte immédiatement l\'admin', () async {
      const adminUser = UserModel(
        id: 1,
        nom: 'Admin Faso',
        telephone: '+22670000001',
        role: 'admin',
      );
      when(() => mockRepository.login(
            identifier: '+22670000001',
            password: 'AdminPass123!',
          )).thenAnswer((_) async => adminUser);
      when(() => mockRepository.logout()).thenAnswer((_) async {});

      final container = createContainer();
      final notifier = container.read(authNotifierProvider.notifier);

      await notifier.login(
        identifier: '+22670000001',
        password: 'AdminPass123!',
      );
      expect(container.read(authNotifierProvider).user?.role, equals('admin'));

      container.read(sessionExpiredControllerProvider).add(null);
      await Future<void>.delayed(const Duration(milliseconds: 20));

      final afterState = container.read(authNotifierProvider);
      expect(afterState.status, equals(AuthStatus.unauthenticated));
      expect(afterState.user, isNull);
      expect(afterState.isAuthenticated, isFalse);
      verify(() => mockRepository.logout()).called(1);
    });
  });
}
