import 'package:equatable/equatable.dart';
import 'package:qvgestion_mobile/features/auth/data/models/user_model.dart';

/// Réponse retournée par le backend lors d'une connexion ou d'une inscription
class AuthResponseModel extends Equatable {
  final String accessToken;
  final String refreshToken;
  final String tokenType;
  final UserModel? user;

  const AuthResponseModel({
    required this.accessToken,
    required this.refreshToken,
    this.tokenType = 'bearer',
    this.user,
  });

  factory AuthResponseModel.fromJson(Map<String, dynamic> json) {
    return AuthResponseModel(
      accessToken: json['access_token'] as String,
      refreshToken: json['refresh_token'] as String,
      tokenType: (json['token_type'] as String?) ?? 'bearer',
      user: json['user'] != null && json['user'] is Map<String, dynamic>
          ? UserModel.fromJson(json['user'] as Map<String, dynamic>)
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'access_token': accessToken,
      'refresh_token': refreshToken,
      'token_type': tokenType,
      if (user != null) 'user': user!.toJson(),
    };
  }

  @override
  List<Object?> get props => [accessToken, refreshToken, tokenType, user];
}
