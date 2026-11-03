import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/features/admin/data/models/api_key_model.dart';
import 'package:qvgestion_mobile/features/admin/presentation/providers/admin_providers.dart';

/// Dialogue pour générer une nouvelle clé API B2B / B2G FASO NAV
class CreateApiKeyDialog extends ConsumerStatefulWidget {
  const CreateApiKeyDialog({super.key});

  static Future<ApiKeyModel?> show(BuildContext context) {
    return showDialog<ApiKeyModel>(
      context: context,
      builder: (ctx) => const CreateApiKeyDialog(),
    );
  }

  @override
  ConsumerState<CreateApiKeyDialog> createState() => _CreateApiKeyDialogState();
}

class _CreateApiKeyDialogState extends ConsumerState<CreateApiKeyDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _quotaCtrl = TextEditingController(text: '50000');

  String _clientType = ApiClientType.delivery.slug;
  String _tier = ApiTier.pro.slug;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _descCtrl.dispose();
    _quotaCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final quota = int.tryParse(_quotaCtrl.text.trim()) ?? 50000;

    setState(() => _isLoading = true);

    try {
      final keyNotifier = ref.read(adminApiKeysProvider.notifier);
      final newKey = await keyNotifier.createKey(
        name: _nameCtrl.text.trim(),
        clientType: _clientType,
        tier: _tier,
        monthlyQuota: quota,
        description: _descCtrl.text.trim().isNotEmpty ? _descCtrl.text.trim() : null,
      );

      if (mounted) {
        // Afficher dialog de succès avec clé à copier
        await showDialog<void>(
          context: context,
          builder: (ctx) => AlertDialog(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: const Row(
              children: [
                Icon(Icons.vpn_key_rounded, color: Color(0xFF10B981), size: 24),
                SizedBox(width: 10),
                Text('Clé API Générée !', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Voici la clé API pour "${newKey.name}". Copiez-la et transmettez-la de manière sécurisée :',
                  style: const TextStyle(fontSize: 13, color: Color(0xFF64748B)),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E293B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          newKey.key,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            color: Color(0xFF38BDF8),
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
                        onPressed: () {
                          Clipboard.setData(ClipboardData(text: newKey.key));
                          AppSnackbar.showSuccess(ctx, message: 'Clé copiée dans le presse-papier !');
                        },
                        tooltip: 'Copier',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Header requis : X-API-Key: faso_live_...',
                  style: TextStyle(fontSize: 11, fontStyle: FontStyle.italic, color: Color(0xFF94A3B8)),
                ),
              ],
            ),
            actions: [
              ElevatedButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Compris'),
              ),
            ],
          ),
        );

        if (mounted) {
          Navigator.of(context).pop(newKey);
        }
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Erreur lors de la génération de la clé : $e',
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
              color: const Color(0xFFEFF6FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.key_rounded, color: Color(0xFF2563EB), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Nouvelle Clé API B2B / B2G',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Intégration logistique, SAMU, VTC, etc.',
                  style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
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
            children: [
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom du partenaire / service *',
                  hintText: 'ex: SAMU 15 Centre, Faso Logistique',
                  prefixIcon: Icon(Icons.business_rounded, size: 20),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _clientType,
                decoration: const InputDecoration(
                  labelText: 'Secteur d\'activité',
                  prefixIcon: Icon(Icons.hub_rounded, size: 20),
                ),
                items: ApiClientType.values.map((type) {
                  return DropdownMenuItem(
                    value: type.slug,
                    child: Text(type.label),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _clientType = val;
                      if (val == ApiClientType.emergency.slug) {
                        _tier = ApiTier.emergencyPriority.slug;
                        _quotaCtrl.text = '-1';
                      }
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _tier,
                decoration: const InputDecoration(
                  labelText: 'Niveau de Forfait (Tier)',
                  prefixIcon: Icon(Icons.military_tech_rounded, size: 20),
                ),
                items: ApiTier.values.map((tier) {
                  return DropdownMenuItem(
                    value: tier.slug,
                    child: Text(tier.label),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) {
                    setState(() {
                      _tier = val;
                      if (val == ApiTier.starter.slug) _quotaCtrl.text = '50000';
                      if (val == ApiTier.pro.slug) _quotaCtrl.text = '500000';
                      if (val == ApiTier.enterprise.slug) _quotaCtrl.text = '5000000';
                      if (val == ApiTier.emergencyPriority.slug) _quotaCtrl.text = '-1';
                    });
                  }
                },
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _quotaCtrl,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quota mensuel (-1 pour illimité)',
                  hintText: '50000',
                  prefixIcon: Icon(Icons.speed_rounded, size: 20),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Usage prévu / Description',
                  hintText: 'ex: Algorithme de dispatching coursiers moto',
                  prefixIcon: Icon(Icons.notes_rounded, size: 20),
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
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.vpn_key_rounded, size: 18),
          label: const Text('Générer la Clé'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

