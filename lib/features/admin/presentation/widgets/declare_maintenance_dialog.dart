import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/features/admin/presentation/providers/admin_providers.dart';
import 'package:qvgestion_mobile/features/admin/presentation/widgets/admin_map_point_picker_dialog.dart';
import 'package:qvgestion_mobile/features/reports/presentation/providers/reports_providers.dart';

/// Dialogue pour déclarer des travaux de voirie / coupure avec impact direct sur le moteur de guidage
class DeclareMaintenanceDialog extends ConsumerStatefulWidget {
  final double? initialLat;
  final double? initialLon;

  const DeclareMaintenanceDialog({
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
      builder: (ctx) => DeclareMaintenanceDialog(
        initialLat: initialLat,
        initialLon: initialLon,
      ),
    );
  }

  @override
  ConsumerState<DeclareMaintenanceDialog> createState() =>
      _DeclareMaintenanceDialogState();
}

class _DeclareMaintenanceDialogState extends ConsumerState<DeclareMaintenanceDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleCtrl;
  late final TextEditingController _descCtrl;
  late final TextEditingController _latCtrl;
  late final TextEditingController _lonCtrl;
  int _durationHours = 48;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleCtrl = TextEditingController(text: 'Travaux de voirie - Voie coupée');
    _descCtrl = TextEditingController(
      text: 'Chantier en cours. Voie inaccessible aux véhicules, déviation recommandée.',
    );
    _latCtrl = TextEditingController(
      text: (widget.initialLat ?? 12.3680).toStringAsFixed(6),
    );
    _lonCtrl = TextEditingController(
      text: (widget.initialLon ?? -1.5270).toStringAsFixed(6),
    );
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
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
      await repo.declareRoadMaintenance(
        latitude: lat,
        longitude: lon,
        title: _titleCtrl.text.trim(),
        description: _descCtrl.text.trim(),
        durationHours: _durationHours,
      );

      ref.invalidate(activeReportsProvider);

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message: 'Travaux déclarés : itinéraire et guidage recalculés !',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Erreur lors de la déclaration : $e',
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
              color: const Color(0xFFFEE2E2),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.construction_rounded, color: Color(0xFFDC2626), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Déclarer Travaux / Coupure',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Recalcul dynamique Valhalla pour les usagers',
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
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Titre des travaux *',
                  hintText: 'ex: Pose de caniveaux Rue 14.12',
                  prefixIcon: Icon(Icons.title_rounded, size: 20),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _descCtrl,
                maxLines: 2,
                decoration: const InputDecoration(
                  labelText: 'Description / Déviation *',
                  prefixIcon: Icon(Icons.description_rounded, size: 20),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: _durationHours,
                decoration: const InputDecoration(
                  labelText: 'Durée estimée de la coupure',
                  prefixIcon: Icon(Icons.timer_rounded, size: 20),
                ),
                items: const [
                  DropdownMenuItem(value: 12, child: Text('12 Heures (Travaux éclairs)')),
                  DropdownMenuItem(value: 24, child: Text('24 Heures (1 Jour)')),
                  DropdownMenuItem(value: 48, child: Text('48 Heures (2 Jours)')),
                  DropdownMenuItem(value: 72, child: Text('72 Heures (3 Jours)')),
                  DropdownMenuItem(value: 168, child: Text('1 Semaine (Gros œuvre)')),
                  DropdownMenuItem(value: 720, child: Text('1 Mois (Chantier lourd)')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _durationHours = val);
                },
              ),
              const SizedBox(height: 14),
              // Bouton interactif de pointage cartographique
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  key: const Key('declare_maintenance_pick_map_button'),
                  icon: const Icon(Icons.map_rounded, size: 18),
                  label: const Text('Pointer la coupure sur la Carte 📍'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFEE2E2),
                    foregroundColor: const Color(0xFFDC2626),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                      side: const BorderSide(color: Color(0xFFFECACA)),
                    ),
                  ),
                  onPressed: () async {
                    final curLat = double.tryParse(_latCtrl.text.trim()) ??
                        widget.initialLat ??
                        12.3680;
                    final curLon = double.tryParse(_lonCtrl.text.trim()) ??
                        widget.initialLon ??
                        -1.5270;
                    final picked = await AdminMapPointPickerDialog.pickPoint(
                      context,
                      initialPoint: LatLng(curLat, curLon),
                      title: 'Point de blocage / Travaux',
                      subtitle: 'Touchez la rue ou le tronçon à bloquer',
                      confirmLabel: 'Bloquer cette voie ici',
                      confirmIcon: Icons.block_rounded,
                      themeColor: const Color(0xFFDC2626),
                    );
                    if (picked != null) {
                      setState(() {
                        _latCtrl.text = picked.latitude.toStringAsFixed(6);
                        _lonCtrl.text = picked.longitude.toStringAsFixed(6);
                      });
                    }
                  },
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
              : const Icon(Icons.block_rounded, size: 18),
          label: const Text('Bloquer la Voie'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

