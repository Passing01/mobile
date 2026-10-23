import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/core/config/app_constants.dart';
import 'package:qvgestion_mobile/core/network/api_client.dart';
import 'package:qvgestion_mobile/core/network/api_endpoints.dart';
import 'package:qvgestion_mobile/core/storage/secure_storage_service.dart';
import 'package:qvgestion_mobile/core/storage/token_storage.dart';
import 'package:qvgestion_mobile/features/auth/data/repositories/auth_repository.dart';

class MockApiClient extends Mock implements ApiClient {}
class MockTokenStorage extends Mock implements TokenStorage {}
class MockSecureStorage extends Mock implements ISecureStorage {}

void main() {
  late MockApiClient mockApiClient;
  late MockTokenStorage mockTokenStorage;
  late MockSecureStorage mockSecureStorage;
  late AuthRepository repository;

  setUp(() {
    mockApiClient = MockApiClient();
    mockTokenStorage = MockTokenStorage();
    mockSecureStorage = MockSecureStorage();

    repository = AuthRepository(
      apiClient: mockApiClient,
      tokenStorage: mockTokenStorage,
      secureStorage: mockSecureStorage,
    );
  });

  group('AuthRepository Tests', () {
    const testUserJson = {
      'id': 14,
      'nom': 'Rasmané Ouedraogo',
      'email': 'rasmane@example.bf',
      'telephone': '+22670223344',
      'role': 'user',
      'langue_preferee': 'mos',
      'is_active': true,
    };

    const testAuthResponseJson = {
      'access_token': 'test_access_token',
      'refresh_token': 'test_refresh_token',
      'token_type': 'bearer',
      'user': testUserJson,
    };

    test('login sauvegarde les tokens et le profil utilisateur en local', () async {
      when(() => mockApiClient.post(
            ApiEndpoints.login,
            data: {'identifiant': '+22670223344', 'mot_de_passe': 'Burkina2026!'},
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.login),
            statusCode: 200,
            data: testAuthResponseJson,
          ));

      when(() => mockTokenStorage.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          )).thenAnswer((_) async {});

      when(() => mockSecureStorage.write(
            key: AppConstants.keyUserProfile,
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final user = await repository.login(
        identifier: '+22670223344',
        password: 'Burkina2026!',
      );

      expect(user.id, equals(14));
      expect(user.nom, equals('Rasmané Ouedraogo'));
      expect(user.telephone, equals('+22670223344'));

      verify(() => mockTokenStorage.saveTokens(
            accessToken: 'test_access_token',
            refreshToken: 'test_refresh_token',
          )).called(1);

      verify(() => mockSecureStorage.write(
            key: AppConstants.keyUserProfile,
            value: any(named: 'value'),
          )).called(1);
    });

    test('register envoie la langue préférée et sauvegarde la session', () async {
      when(() => mockApiClient.post(
            ApiEndpoints.register,
            data: {
              'nom': 'Rasmané Ouedraogo',
              'telephone': '+22670223344',
              'mot_de_passe': 'Burkina2026!',
              'langue_preferee': 'mos',
            },
          )).thenAnswer((_) async => Response(
            requestOptions: RequestOptions(path: ApiEndpoints.register),
            statusCode: 201,
            data: testAuthResponseJson,
          ));

      when(() => mockTokenStorage.saveTokens(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
          )).thenAnswer((_) async {});

      when(() => mockSecureStorage.write(
            key: AppConstants.keyUserProfile,
            value: any(named: 'value'),
          )).thenAnswer((_) async {});

      final user = await repository.register(
        nom: 'Rasmané Ouedraogo',
        telephone: '+22670223344',
        password: 'Burkina2026!',
        languePreferee: 'mos',
      );

      expect(user.id, equals(14));
      expect(user.languePreferee, equals('mos'));
      verify(() => mockTokenStorage.saveTokens(
            accessToken: 'test_access_token',
            refreshToken: 'test_refresh_token',
          )).called(1);
    });

    test('logout purge les tokens et le cache local', () async {
      when(() => mockTokenStorage.clearTokens()).thenAnswer((_) async {});
      when(() => mockSecureStorage.delete(key: AppConstants.keyUserProfile))
          .thenAnswer((_) async {});

      await repository.logout();

      verify(() => mockTokenStorage.clearTokens()).called(1);
      verify(() => mockSecureStorage.delete(key: AppConstants.keyUserProfile)).called(1);
    });
  });
}
