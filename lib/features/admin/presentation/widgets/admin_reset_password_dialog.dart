import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/features/admin/presentation/providers/admin_providers.dart';
import 'package:qvgestion_mobile/features/auth/data/models/user_model.dart';

/// Dialogue pour réinitialiser le mot de passe d'un utilisateur / administrateur
class AdminResetPasswordDialog extends ConsumerStatefulWidget {
  final UserModel user;

  const AdminResetPasswordDialog({super.key, required this.user});

  static Future<bool?> show(BuildContext context, {required UserModel user}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AdminResetPasswordDialog(user: user),
    );
  }

  @override
  ConsumerState<AdminResetPasswordDialog> createState() =>
      _AdminResetPasswordDialogState();
}

class _AdminResetPasswordDialogState
    extends ConsumerState<AdminResetPasswordDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _passwordCtrl;
  bool _obscure = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _passwordCtrl = TextEditingController(text: _generateRandomPassword());
  }

  @override
  void dispose() {
    _passwordCtrl.dispose();
    super.dispose();
  }

  String _generateRandomPassword() {
    const chars = 'abcdefghjkmnpqrstuvwxyzABCDEFGHJKMNPQRSTUVWXYZ23456789!@#%*';
    final rnd = Random.secure();
    return List.generate(10, (_) => chars[rnd.nextInt(chars.length)]).join();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final newPass = _passwordCtrl.text.trim();
    setState(() => _isLoading = true);

    try {
      await ref
          .read(adminUsersProvider.notifier)
          .resetPassword(widget.user.id, newPass);

      // Copier automatiquement le mot de passe dans le presse-papier
      await Clipboard.setData(ClipboardData(text: newPass));

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message:
              'Mot de passe de ${widget.user.nom} réinitialisé et copié dans le presse-papier !',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Erreur lors de la réinitialisation : $e',
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFFFEF2F2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.lock_reset_rounded,
                color: Color(0xFFDC2626), size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Réinitialiser le Mot de Passe',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  widget.user.nom,
                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Définissez un nouveau mot de passe pour le compte #${widget.user.id} (${widget.user.email ?? widget.user.telephone}) :',
                style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
              ),
              const SizedBox(height: 14),
              TextFormField(
                controller: _passwordCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe *',
                  prefixIcon: const Icon(Icons.password_rounded, size: 20),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          _obscure
                              ? Icons.visibility_rounded
                              : Icons.visibility_off_rounded,
                          size: 18,
                        ),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                      IconButton(
                        icon: const Icon(Icons.casino_rounded,
                            size: 18, color: AppColors.primary),
                        tooltip: 'Générer un autre',
                        onPressed: () {
                          setState(() {
                            _passwordCtrl.text = _generateRandomPassword();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                validator: (val) {
                  if (val == null || val.trim().length < 8) {
                    return 'Minimum 8 caractères';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFF1F5F9),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.info_outline_rounded,
                        size: 16, color: Color(0xFF64748B)),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Le nouveau mot de passe sera copié dans le presse-papier dès validation.',
                        style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _isLoading ? null : _submit,
          icon: _isLoading
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.check_rounded, size: 18),
          label: const Text('Réinitialiser'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

