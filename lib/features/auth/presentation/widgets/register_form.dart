import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/theme/app_spacing.dart';
import 'package:qvgestion_mobile/core/utils/validators.dart';
import 'package:qvgestion_mobile/core/widgets/buttons/app_primary_button.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/features/auth/presentation/providers/auth_notifier.dart';
import 'package:qvgestion_mobile/features/auth/presentation/widgets/language_selector_chips.dart';

class RegisterForm extends ConsumerStatefulWidget {
  final VoidCallback onSuccess;

  const RegisterForm({super.key, required this.onSuccess});

  @override
  ConsumerState<RegisterForm> createState() => _RegisterFormState();
}

class _RegisterFormState extends ConsumerState<RegisterForm> {
  final _formKey = GlobalKey<FormState>();
  final _nomController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  String _selectedLanguage = 'mos';
  bool _obscurePassword = true;

  @override
  void dispose() {
    _nomController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    final phone = Validators.normalizeBurkinaPhone(_phoneController.text.trim());

    final success = await ref.read(authNotifierProvider.notifier).register(
          nom: _nomController.text.trim(),
          telephone: phone,
          email: _emailController.text.trim().isNotEmpty ? _emailController.text.trim() : null,
          password: _passwordController.text,
          languePreferee: _selectedLanguage,
        );

    if (success && mounted) {
      AppSnackbar.showSuccess(
        context,
        title: 'Compte créé avec succès',
        message: 'Bienvenue dans la communauté de navigation QvGestion !',
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
          // Nom complet
          TextFormField(
            controller: _nomController,
            decoration: const InputDecoration(
              labelText: 'Nom et Prénom',
              hintText: 'Ex: Rasmané Ouedraogo',
              prefixIcon: Icon(Icons.person_outline_rounded),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Veuillez renseigner votre nom' : null,
          ),
          const SizedBox(height: AppSpacing.md),
          // Téléphone Burkina Faso
          TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(
              labelText: 'Téléphone (Burkina Faso)',
              hintText: '+226 70 22 33 44',
              prefixIcon: Icon(Icons.phone_android_rounded),
            ),
            validator: Validators.validateBurkinaPhone,
          ),
          const SizedBox(height: AppSpacing.md),
          // Email (optionnel)
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'Email (optionnel)',
              hintText: 'rasmane@example.bf',
              prefixIcon: Icon(Icons.mail_outline_rounded),
            ),
            validator: (v) {
              if (v == null || v.trim().isEmpty) return null;
              return Validators.validateEmail(v);
            },
          ),
          const SizedBox(height: AppSpacing.md),
          // Mot de passe
          TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            decoration: InputDecoration(
              labelText: 'Mot de passe (8 caractères min.)',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword ? Icons.visibility_off_rounded : Icons.visibility_rounded,
                  color: AppColors.textSecondaryLight,
                ),
                onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
              ),
            ),
            validator: Validators.validatePassword,
          ),
          const SizedBox(height: AppSpacing.lg),
          // Sélection de langue préférée pour le guidage vocal
          const Text(
            'Langue préférée pour les consignes vocales',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          LanguageSelectorChips(
            selectedCode: _selectedLanguage,
            onSelected: (code) => setState(() => _selectedLanguage = code),
          ),
          const SizedBox(height: AppSpacing.xl),
          // Bouton d'inscription
          AppPrimaryButton(
            label: 'Créer mon compte',
            icon: Icons.person_add_alt_1_rounded,
            isLoading: authState.isLoading,
            onPressed: _handleSubmit,
          ),
        ],
      ),
    );
  }
}
