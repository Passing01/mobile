import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:qvgestion_mobile/core/config/app_constants.dart';
import 'package:qvgestion_mobile/core/storage/secure_storage_service.dart';
import 'package:qvgestion_mobile/core/storage/token_storage.dart';

class MockSecureStorage extends Mock implements ISecureStorage {}

void main() {
  late MockSecureStorage mockStorage;
  late TokenStorage tokenStorage;

  setUp(() {
    mockStorage = MockSecureStorage();
    tokenStorage = TokenStorage(storage: mockStorage);
  });

  group('TokenStorage Tests', () {
    const testAccessToken = 'test_access_token_123';
    const testRefreshToken = 'test_refresh_token_456';

    test('saveTokens écrit l\'access_token et le refresh_token', () async {
      when(() => mockStorage.write(
            key: AppConstants.keyAccessToken,
            value: testAccessToken,
          )).thenAnswer((_) async {});
      when(() => mockStorage.write(
            key: AppConstants.keyRefreshToken,
            value: testRefreshToken,
          )).thenAnswer((_) async {});

      await tokenStorage.saveTokens(
        accessToken: testAccessToken,
        refreshToken: testRefreshToken,
      );

      verify(() => mockStorage.write(
            key: AppConstants.keyAccessToken,
            value: testAccessToken,
          )).called(1);
      verify(() => mockStorage.write(
            key: AppConstants.keyRefreshToken,
            value: testRefreshToken,
          )).called(1);
    });

    test('getAccessToken lit la valeur depuis le stockage', () async {
      when(() => mockStorage.read(key: AppConstants.keyAccessToken))
          .thenAnswer((_) async => testAccessToken);

      final result = await tokenStorage.getAccessToken();

      expect(result, equals(testAccessToken));
      verify(() => mockStorage.read(key: AppConstants.keyAccessToken)).called(1);
    });

    test('getRefreshToken lit la valeur depuis le stockage', () async {
      when(() => mockStorage.read(key: AppConstants.keyRefreshToken))
          .thenAnswer((_) async => testRefreshToken);

      final result = await tokenStorage.getRefreshToken();

      expect(result, equals(testRefreshToken));
      verify(() => mockStorage.read(key: AppConstants.keyRefreshToken)).called(1);
    });

    test('hasAccessToken retourne vrai si le token est présent et non vide', () async {
      when(() => mockStorage.read(key: AppConstants.keyAccessToken))
          .thenAnswer((_) async => testAccessToken);

      final hasToken = await tokenStorage.hasAccessToken();
      expect(hasToken, isTrue);

      when(() => mockStorage.read(key: AppConstants.keyAccessToken))
          .thenAnswer((_) async => null);

      final hasNoToken = await tokenStorage.hasAccessToken();
      expect(hasNoToken, isFalse);
    });

    test('clearTokens supprime les deux jetons', () async {
      when(() => mockStorage.delete(key: any(named: 'key')))
          .thenAnswer((_) async {});

      await tokenStorage.clearTokens();

      verify(() => mockStorage.delete(key: AppConstants.keyAccessToken)).called(1);
      verify(() => mockStorage.delete(key: AppConstants.keyRefreshToken)).called(1);
    });

    test('isJwtExpired détecte correctement l\'expiration d\'un token JWT', () {
      // Génération d'un faux token JWT expiré (exp dans le passé)
      final pastExp = DateTime.now().subtract(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      final pastPayload = base64Url.encode(utf8.encode(jsonEncode({'exp': pastExp, 'sub': 'user1'})));
      final expiredToken = 'header.$pastPayload.signature';

      expect(TokenStorage.isJwtExpired(expiredToken), isTrue);

      // Génération d'un faux token JWT valide (exp dans 1 heure)
      final futureExp = DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch ~/ 1000;
      final futurePayload = base64Url.encode(utf8.encode(jsonEncode({'exp': futureExp, 'sub': 'user1'})));
      final validToken = 'header.$futurePayload.signature';

      expect(TokenStorage.isJwtExpired(validToken), isFalse);

      // Format invalide
      expect(TokenStorage.isJwtExpired('invalid_token_format'), isTrue);
    });
  });
}
