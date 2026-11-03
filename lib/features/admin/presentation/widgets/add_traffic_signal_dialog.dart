import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/features/admin/presentation/providers/admin_providers.dart';

/// Dialogue pour déposer un feu tricolore opérationnel pour le guidage vocal (Narrateur v2)
class AddTrafficSignalDialog extends ConsumerStatefulWidget {
  final double? initialLat;
  final double? initialLon;

  const AddTrafficSignalDialog({
    super.key,
    this.initialLat,
    this.initialLon,
  });

  static Future<bool?> show(
    BuildContext context, {
    double? initialLat,
    double? initialLon,
  }) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AddTrafficSignalDialog(
        initialLat: initialLat,
        initialLon: initialLon,
      ),
    );
  }

  @override
  ConsumerState<AddTrafficSignalDialog> createState() =>
      _AddTrafficSignalDialogState();
}

class _AddTrafficSignalDialogState extends ConsumerState<AddTrafficSignalDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _crossroadCtrl;
  late final TextEditingController _directionCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lonCtrl;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: 'Feu Tricolore ');
    _crossroadCtrl = TextEditingController();
    _directionCtrl = TextEditingController();
    _latCtrl = TextEditingController(
      text: (widget.initialLat ?? 12.3680).toStringAsFixed(6),
    );
    _lonCtrl = TextEditingController(
      text: (widget.initialLon ?? -1.5270).toStringAsFixed(6),
    );
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _crossroadCtrl.dispose();
    _directionCtrl.dispose();
    _latCtrl.dispose();
    _lonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final lat = double.tryParse(_latCtrl.text.trim());
    final lon = double.tryParse(_lonCtrl.text.trim());

    if (lat == null || lon == null) {
      AppSnackbar.showError(context, message: 'Coordonnées GPS invalides');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(adminRepositoryProvider);
      await repo.addTrafficSignal(
        latitude: lat,
        longitude: lon,
        name: _nameCtrl.text.trim(),
        crossroadName: _crossroadCtrl.text.trim().isNotEmpty
            ? _crossroadCtrl.text.trim()
            : null,
        direction: _directionCtrl.text.trim().isNotEmpty
            ? _directionCtrl.text.trim()
            : null,
      );

      ref.invalidate(adminRoadFeaturesProvider);

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message: 'Feu tricolore ajouté et intégré au guidage vocal !',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Erreur lors de l\'enregistrement du feu : $e',
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
              color: const Color(0xFFFEF3C7),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.traffic_rounded, color: Color(0xFFD97706), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Déposer un Feu Tricolore',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Actif pour les voix Moore, Dioula & FR',
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
                  labelText: 'Nom du feu *',
                  hintText: 'ex: Feu Carrefour Échangeur Est',
                  prefixIcon: Icon(Icons.label_rounded, size: 20),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _crossroadCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom du carrefour / repère',
                  hintText: 'ex: Rond-point Charles de Gaulle',
                  prefixIcon: Icon(Icons.alt_route_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _directionCtrl,
                decoration: const InputDecoration(
                  labelText: 'Axe / Direction prioritaire',
                  hintText: 'ex: Vers Ouaga 2000',
                  prefixIcon: Icon(Icons.explore_rounded, size: 20),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _latCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Latitude *',
                        prefixIcon: Icon(Icons.pin_drop_rounded, size: 18),
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Requis' : null,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _lonCtrl,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                        signed: true,
                      ),
                      decoration: const InputDecoration(
                        labelText: 'Longitude *',
                        prefixIcon: Icon(Icons.pin_drop_rounded, size: 18),
                      ),
                      validator: (val) =>
                          (val == null || val.trim().isEmpty) ? 'Requis' : null,
                    ),
                  ),
                ],
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
              : const Icon(Icons.check_circle_rounded, size: 18),
          label: const Text('Enregistrer le Feu'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

