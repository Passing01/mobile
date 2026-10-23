import 'package:qvgestion_mobile/core/config/app_constants.dart';

/// Utilitaires de validation pour les formulaires et les données métier burkinabè
class Validators {
  // Regex pour numéro de téléphone burkinabè (+226 ou 00226 optionnel suivi de 8 chiffres)
  static final RegExp _burkinaPhoneRegex = RegExp(
    r'^(?:\+226|00226)?([0-9]{8})$',
  );

  // Regex standard pour validation d'email
  static final RegExp _emailRegex = RegExp(
    r'^[a-zA-Z0-9.!#$%&’*+/=?^_`{|}~-]+@[a-zA-Z0-9-]+(?:\.[a-zA-Z0-9-]+)+$',
  );

  /// Valide un numéro de téléphone au format burkinabè (+226 suivi de 8 chiffres)
  static String? validateBurkinaPhone(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez saisir votre numéro de téléphone';
    }

    final cleaned = value.replaceAll(RegExp(r'\s+'), '');
    if (!_burkinaPhoneRegex.hasMatch(cleaned)) {
      return 'Numéro invalide. Format attendu: +226 suivi de 8 chiffres (ex: +22670223344)';
    }

    return null;
  }

  /// Normalise un numéro de téléphone burkinabè vers le format international standard (+226XXXXXXXX)
  static String normalizeBurkinaPhone(String phone) {
    final cleaned = phone.replaceAll(RegExp(r'[\s\-()]'), '');
    final match = _burkinaPhoneRegex.firstMatch(cleaned);
    if (match != null && match.groupCount >= 1) {
      final eightDigits = match.group(1)!;
      return '${AppConstants.burkinaCountryCode}$eightDigits';
    }
    return phone;
  }

  /// Valide une adresse email
  static String? validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez saisir une adresse email';
    }

    if (!_emailRegex.hasMatch(value.trim())) {
      return 'Adresse email invalide';
    }

    return null;
  }

  /// Valide un mot de passe (au moins 8 caractères selon les critères backend)
  static String? validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Veuillez saisir un mot de passe';
    }

    if (value.length < 8) {
      return 'Le mot de passe doit comporter au moins 8 caractères';
    }

    return null;
  }

  /// Valide un identifiant (peut être soit un email, soit un numéro burkinabè)
  static String? validateIdentifier(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Veuillez saisir votre email ou votre numéro de téléphone';
    }

    final trimmed = value.trim();
    final isEmail = _emailRegex.hasMatch(trimmed);
    final isPhone = _burkinaPhoneRegex.hasMatch(trimmed.replaceAll(RegExp(r'\s+'), ''));

    if (!isEmail && !isPhone) {
      return 'Saisissez une adresse email valide ou un numéro burkinabè (+226...)';
    }

    return null;
  }

  /// Vérifie si des coordonnées géographiques sont situées dans les limites du Burkina Faso
  static bool isWithinBurkinaFaso(double latitude, double longitude) {
    return latitude >= AppConstants.burkinaMinLatitude &&
        latitude <= AppConstants.burkinaMaxLatitude &&
        longitude >= AppConstants.burkinaMinLongitude &&
        longitude <= AppConstants.burkinaMaxLongitude;
  }
}
