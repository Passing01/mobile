import 'package:flutter_test/flutter_test.dart';
import 'package:qvgestion_mobile/core/utils/validators.dart';

void main() {
  group('Validators - Téléphone Burkinabè', () {
    test('Valide les numéros au format international +226', () {
      expect(Validators.validateBurkinaPhone('+22670223344'), isNull);
      expect(Validators.validateBurkinaPhone('+22660112233'), isNull);
      expect(Validators.validateBurkinaPhone('+22651001122'), isNull);
      expect(Validators.validateBurkinaPhone('0022670223344'), isNull);
    });

    test('Valide les numéros nationaux à 8 chiffres', () {
      expect(Validators.validateBurkinaPhone('70223344'), isNull);
      expect(Validators.validateBurkinaPhone('60112233'), isNull);
    });

    test('Rejette les numéros invalides ou trop courts/longs', () {
      expect(Validators.validateBurkinaPhone(''), isNotNull);
      expect(Validators.validateBurkinaPhone(null), isNotNull);
      expect(Validators.validateBurkinaPhone('12345'), isNotNull);
      expect(Validators.validateBurkinaPhone('+33612345678'), isNotNull); // Numéro français
      expect(Validators.validateBurkinaPhone('+2267022334455'), isNotNull); // Trop long
      expect(Validators.validateBurkinaPhone('abcdefgh'), isNotNull);
    });

    test('Normalise vers le format canonique +226XXXXXXXX', () {
      expect(Validators.normalizeBurkinaPhone('+22670223344'), equals('+22670223344'));
      expect(Validators.normalizeBurkinaPhone('0022670223344'), equals('+22670223344'));
      expect(Validators.normalizeBurkinaPhone('70223344'), equals('+22670223344'));
      expect(Validators.normalizeBurkinaPhone('70 22 33 44'), equals('+22670223344'));
      expect(Validators.normalizeBurkinaPhone('+226 70-22-33-44'), equals('+22670223344'));
    });
  });

  group('Validators - Email', () {
    test('Valide les adresses emails conformes', () {
      expect(Validators.validateEmail('user@example.bf'), isNull);
      expect(Validators.validateEmail('rasmane.ouedraogo@faso.gov.bf'), isNull);
    });

    test('Rejette les adresses emails invalides', () {
      expect(Validators.validateEmail(''), isNotNull);
      expect(Validators.validateEmail(null), isNotNull);
      expect(Validators.validateEmail('invalid-email'), isNotNull);
      expect(Validators.validateEmail('@domain.com'), isNotNull);
    });
  });

  group('Validators - Mot de passe', () {
    test('Valide les mots de passe de 8 caractères ou plus', () {
      expect(Validators.validatePassword('Burkina2026!'), isNull);
      expect(Validators.validatePassword('12345678'), isNull);
    });

    test('Rejette les mots de passe trop courts ou vides', () {
      expect(Validators.validatePassword('1234567'), isNotNull);
      expect(Validators.validatePassword(''), isNotNull);
      expect(Validators.validatePassword(null), isNotNull);
    });
  });

  group('Validators - Identifiant mixte (Email ou Téléphone)', () {
    test('Accepte indifféremment un email ou un numéro burkinabè', () {
      expect(Validators.validateIdentifier('user@qvgestion.bf'), isNull);
      expect(Validators.validateIdentifier('+22670223344'), isNull);
      expect(Validators.validateIdentifier('70223344'), isNull);
    });

    test('Rejette les identifiants qui ne sont ni email ni téléphone burkinabè', () {
      expect(Validators.validateIdentifier('invalid_id'), isNotNull);
      expect(Validators.validateIdentifier(''), isNotNull);
      expect(Validators.validateIdentifier(null), isNotNull);
    });
  });

  group('Validators - Limites géographiques du Burkina Faso', () {
    test('Accepte les coordonnées situées au Burkina Faso', () {
      // Ouagadougou
      expect(Validators.isWithinBurkinaFaso(12.3685, -1.5271), isTrue);
      // Bobo-Dioulasso
      expect(Validators.isWithinBurkinaFaso(11.1772, -4.2979), isTrue);
      // Koudougou
      expect(Validators.isWithinBurkinaFaso(12.2526, -2.3627), isTrue);
    });

    test('Rejette les coordonnées hors du Burkina Faso', () {
      // Paris, France (48.8566, 2.3522)
      expect(Validators.isWithinBurkinaFaso(48.8566, 2.3522), isFalse);
      // Abidjan, Côte d'Ivoire (5.3600, -4.0083) - latitude trop basse
      expect(Validators.isWithinBurkinaFaso(5.3600, -4.0083), isFalse);
      // Lomé, Togo (6.1375, 1.2125)
      expect(Validators.isWithinBurkinaFaso(6.1375, 1.2125), isFalse);
    });
  });
}
