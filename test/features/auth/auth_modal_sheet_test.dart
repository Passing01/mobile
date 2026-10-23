import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/features/auth/data/models/user_model.dart';
import 'package:qvgestion_mobile/features/auth/data/repositories/auth_repository.dart';
import 'package:qvgestion_mobile/features/auth/presentation/providers/auth_notifier.dart';
import 'package:qvgestion_mobile/features/auth/presentation/providers/auth_state.dart';
import 'package:qvgestion_mobile/features/auth/presentation/widgets/auth_modal_sheet.dart';

class MockAuthRepository extends Mock implements IAuthRepository {}

class FakeAuthNotifier extends AuthNotifier {
  final AuthState initialState;
  FakeAuthNotifier(this.initialState);

  @override
  AuthState build() => initialState;
}

void main() {
  late MockAuthRepository mockRepository;

  setUp(() {
    mockRepository = MockAuthRepository();
    when(() => mockRepository.isAuthenticated()).thenAnswer((_) async => false);
  });

  group('AuthModalSheet Widget Tests', () {
    testWidgets('Affiche les formulaires de connexion et d\'inscription quand déconnecté',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepository),
            authNotifierProvider.overrideWith(
              () => FakeAuthNotifier(const AuthState(status: AuthStatus.unauthenticated)),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AuthModalSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Vérifie les onglets
      expect(find.text('Espace Utilisateur'), findsOneWidget);
      expect(find.text('Se connecter'), findsNWidgets(2)); // Onglet + Bouton
      expect(find.text('Créer un compte'), findsOneWidget);

      // Clic sur l'onglet 'Créer un compte'
      await tester.tap(find.text('Créer un compte'));
      await tester.pumpAndSettle();

      // Vérifie les champs d'inscription
      expect(find.text('Nom et Prénom'), findsOneWidget);
      expect(find.text('Téléphone (Burkina Faso)'), findsOneWidget);
      expect(find.text('Mooré'), findsOneWidget);
      expect(find.text('Dioula'), findsOneWidget);
      expect(find.text('Français'), findsOneWidget);
      expect(find.text('Créer mon compte'), findsOneWidget);
    });

    testWidgets('Affiche le profil utilisateur et le bouton déconnexion quand connecté',
        (WidgetTester tester) async {
      const loggedUser = UserModel(
        id: 14,
        nom: 'Rasmané Ouedraogo',
        telephone: '+22670223344',
        email: 'rasmane@example.bf',
        role: 'user',
        languePreferee: 'mos',
      );

      when(() => mockRepository.isAuthenticated()).thenAnswer((_) async => true);
      when(() => mockRepository.getCurrentUser()).thenAnswer((_) async => loggedUser);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authRepositoryProvider.overrideWithValue(mockRepository),
            authNotifierProvider.overrideWith(
              () => FakeAuthNotifier(
                const AuthState(
                  status: AuthStatus.authenticated,
                  user: loggedUser,
                ),
              ),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(
              body: AuthModalSheet(),
            ),
          ),
        ),
      );

      await tester.pumpAndSettle();

      // Vérifie l'affichage du profil connecté
      expect(find.text('Rasmané Ouedraogo'), findsOneWidget);
      expect(find.text('+22670223344'), findsOneWidget);
      expect(find.text('rasmane@example.bf'), findsOneWidget);
      expect(find.text('RO'), findsOneWidget); // Initiales
      expect(find.text('Se déconnecter'), findsOneWidget);
    });
  });
}
