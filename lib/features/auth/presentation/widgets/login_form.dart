import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/theme/app_spacing.dart';
import 'package:qvgestion_mobile/core/utils/validators.dart';
import 'package:qvgestion_mobile/core/widgets/buttons/app_primary_button.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/features/auth/presentation/providers/auth_notifier.dart';

class LoginForm extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const LoginForm({super.key, required this.onSuccess});

  @override
  ConsumerState<LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<LoginForm> {
  final _formKey = GlobalKey<FormState>();
  final _identifierController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;

  @override
  void dispose() {
    _identifierController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final identifier = _identifierController.text.trim();
    final normalized = Validators.normalizeBurkinaPhone(identifier);
    final password = _passwordController.text;

    final success = await ref.read(authNotifierProvider.notifier).login(
          identifier: normalized,
          password: password,
        );

    if (success && mounted) {
      AppSnackbar.showSuccess(
        context,
        title: 'Connexion réussie',
        message: 'Bienvenue sur QvGestion Mobile !',
      );
      widget.onSuccess();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authNotifierProvider);

    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (authState.errorMessage != null) ...[
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.1),
                borderRadius: AppSpacing.roundedSm,
                border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: AppColors.secondary, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      authState.errorMessage!,
                      style: const TextStyle(
                        color: AppColors.secondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
          ],
          // Champ Identifiant (Email ou Numéro +226)
          TextFormField(
            controller: _identifierController,
            keyboardType: TextInputType.text,
            decoration: InputDecoration(
              labelText: 'Email ou Téléphone burkinabè',
              hintText: '+22670223344 ou nom@domaine.bf',
              prefixIcon: const Icon(Icons.person_outline_rounded),
            ),
            validator: Validators.validateIdentifier,
          ),
          const SizedBox(height: AppSpacing.md),
          // Champ Mot de passe
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: AppColors.textSecondaryLight,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: (v) => (v == null || v.isEmpty) ? 'Veuillez saisir votre mot de passe' : null,
          ),
          const SizedBox(height: AppSpacing.xl),
          // Bouton de connexion
          AppPrimaryButton(
            label: 'Se connecter',
            icon: Icons.login_rounded,
            isLoading: authState.isLoading,
            onPressed: _handleSubmit,
          ),
        ],
      ),
    );
  }
}
