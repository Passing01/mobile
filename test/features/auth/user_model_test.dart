import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/features/auth/data/models/user_model.dart';

void main() {
  group('UserModel Tests', () {
    const userJson = {
      'id': 14,
      'nom': 'Rasmané Ouedraogo',
      'email': 'rasmane@example.bf',
      'telephone': '+22670223344',
      'role': 'user',
      'langue_preferee': 'mos',
      'is_active': true,
    };

    test('fromJson désérialise correctement', () {
      final user = UserModel.fromJson(userJson);

      expect(user.id, equals(14));
      expect(user.nom, equals('Rasmané Ouedraogo'));
      expect(user.email, equals('rasmane@example.bf'));
      expect(user.telephone, equals('+22670223344'));
      expect(user.role, equals('user'));
      expect(user.languePreferee, equals('mos'));
      expect(user.isActive, isTrue);
    });

    test('toJson sérialise fidèlement', () {
      final user = UserModel.fromJson(userJson);
      final json = user.toJson();

      expect(json['id'], equals(14));
      expect(json['nom'], equals('Rasmané Ouedraogo'));
      expect(json['telephone'], equals('+22670223344'));
      expect(json['langue_preferee'], equals('mos'));
    });

    test('initiales génère les deux premières lettres pour un nom composé', () {
      const user = UserModel(
        id: 1,
        nom: 'Rasmané Ouedraogo',
        telephone: '+22670223344',
      );
      expect(user.initiales, equals('RO'));

      const singleName = UserModel(
        id: 2,
        nom: 'Aminata',
        telephone: '+22670112233',
      );
      expect(singleName.initiales, equals('A'));
    });

    test('nomLangue retourne le nom complet en fonction du code', () {
      const userMos = UserModel(id: 1, nom: 'A', telephone: '+226', languePreferee: 'mos');
      expect(userMos.nomLangue, equals('Mooré'));

      const userDiu = UserModel(id: 2, nom: 'B', telephone: '+226', languePreferee: 'diu');
      expect(userDiu.nomLangue, equals('Dioula'));

      const userFr = UserModel(id: 3, nom: 'C', telephone: '+226', languePreferee: 'fr');
      expect(userFr.nomLangue, equals('Français'));
    });

    test('copyWith crée une nouvelle copie avec modifications', () {
      const user = UserModel(id: 1, nom: 'Ali', telephone: '+22670000000', languePreferee: 'fr');
      final updated = user.copyWith(languePreferee: 'mos');

      expect(updated.languePreferee, equals('mos'));
      expect(updated.nom, equals('Ali'));
    });
  });
}
