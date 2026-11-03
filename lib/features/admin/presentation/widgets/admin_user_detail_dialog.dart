import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/features/admin/presentation/providers/admin_providers.dart';
import 'package:qvgestion_mobile/features/admin/presentation/widgets/admin_reset_password_dialog.dart';
import 'package:qvgestion_mobile/features/auth/data/models/user_model.dart';

/// Dialogue affichant les détails complets d'un utilisateur / administrateur
class AdminUserDetailDialog extends ConsumerWidget {
  final UserModel user;

  const AdminUserDetailDialog({super.key, required this.user});

  static Future<void> show(BuildContext context, {required UserModel user}) {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AdminUserDetailDialog(user: user),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = user.role.toLowerCase() == 'admin';
    final isMod = user.role.toLowerCase() == 'moderator';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      title: Row(
        children: [
          CircleAvatar(
            backgroundColor: isAdmin
                ? const Color(0xFFDC2626)
                : (isMod ? const Color(0xFF2563EB) : const Color(0xFF10B981)),
            radius: 20,
            child: Text(
              user.initiales,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  user.nom,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  'Compte #${user.id} • ${user.role.toUpperCase()}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isAdmin
                        ? const Color(0xFFDC2626)
                        : (isMod ? const Color(0xFF2563EB) : const Color(0xFF64748B)),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildInfoRow(
              icon: Icons.email_rounded,
              label: 'Email',
              value: user.email?.isNotEmpty == true ? user.email! : 'Non renseigné',
            ),
            const Divider(height: 16),
            _buildInfoRow(
              icon: Icons.phone_rounded,
              label: 'Téléphone',
              value: user.telephone.isNotEmpty ? user.telephone : 'Non renseigné',
            ),
            const Divider(height: 16),
            _buildInfoRow(
              icon: Icons.language_rounded,
              label: 'Langue de navigation',
              value: '${user.nomLangue} (${user.languePreferee})',
            ),
            const Divider(height: 16),
            _buildInfoRow(
              icon: user.isActive ? Icons.check_circle_rounded : Icons.block_rounded,
              iconColor: user.isActive ? const Color(0xFF10B981) : Colors.red,
              label: 'Statut du compte',
              value: user.isActive ? 'Actif (Autorisé)' : 'Suspendu / Désactivé',
            ),
            const SizedBox(height: 20),

            // Actions directes
            const Text(
              'Actions Administrateur :',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569)),
            ),
            const SizedBox(height: 10),

            // Action 1: Réinitialiser mot de passe
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () {
                  Navigator.of(context).pop();
                  AdminResetPasswordDialog.show(context, user: user);
                },
                icon: const Icon(Icons.lock_reset_rounded, size: 18, color: Color(0xFFDC2626)),
                label: const Text(
                  'Réinitialiser le mot de passe',
                  style: TextStyle(color: Color(0xFFDC2626)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFFECACA)),
                  backgroundColor: const Color(0xFFFEF2F2),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Action 2: Modifier le rôle
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () async {
                  final newRole = await showDialog<String>(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: Text('Modifier le rôle de ${user.nom}'),
                      children: [
                        SimpleDialogOption(
                          onPressed: () => Navigator.of(ctx).pop('admin'),
                          child: const Text('Administrateur (Tous les droits)',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFFDC2626))),
                        ),
                        SimpleDialogOption(
                          onPressed: () => Navigator.of(ctx).pop('moderator'),
                          child: const Text('Modérateur (Lieux & Signalements)',
                              style: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF2563EB))),
                        ),
                        SimpleDialogOption(
                          onPressed: () => Navigator.of(ctx).pop('user'),
                          child: const Text('Utilisateur standard',
                              style: TextStyle(fontWeight: FontWeight.normal)),
                        ),
                      ],
                    ),
                  );

                  if (newRole != null && newRole != user.role) {
                    await ref.read(adminUsersProvider.notifier).changeRole(user.id, newRole);
                    if (context.mounted) {
                      AppSnackbar.showSuccess(context, message: 'Rôle modifié vers $newRole');
                      Navigator.of(context).pop();
                    }
                  }
                },
                icon: const Icon(Icons.manage_accounts_rounded, size: 18, color: Color(0xFF2563EB)),
                label: const Text(
                  'Modifier le rôle / Privilèges',
                  style: TextStyle(color: Color(0xFF2563EB)),
                ),
                style: OutlinedButton.styleFrom(
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                  backgroundColor: const Color(0xFFEFF6FF),
                ),
              ),
            ),
            const SizedBox(height: 8),

            // Action 3: Activer / Désactiver
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: () async {
                  final newActive = !user.isActive;
                  await ref.read(adminUsersProvider.notifier).toggleStatus(user.id, newActive);
                  if (context.mounted) {
                    AppSnackbar.showInfo(
                      context,
                      message: newActive ? 'Compte activé' : 'Compte désactivé',
                    );
                    Navigator.of(context).pop();
                  }
                },
                icon: Icon(user.isActive ? Icons.block_rounded : Icons.check_circle_rounded, size: 18),
                label: Text(user.isActive ? 'Désactiver le compte' : 'Activer le compte'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: user.isActive ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                  foregroundColor: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Fermer'),
        ),
      ],
    );
  }

  Widget _buildInfoRow({
    required IconData icon,
    Color? iconColor,
    required String label,
    required String value,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: iconColor ?? const Color(0xFF64748B)),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

