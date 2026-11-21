import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/features/admin/presentation/providers/admin_providers.dart';
import 'package:qvgestion_mobile/features/admin/presentation/widgets/admin_map_point_picker_dialog.dart';
import 'package:qvgestion_mobile/features/guidance/presentation/providers/guidance_providers.dart';

/// Boîte de dialogue permettant à un administrateur de déposer un bâtiment,
/// monument ou échangeur 3D directement sur la carte Faso 3D.
class AddBuilding3dDialog extends ConsumerStatefulWidget {
  const AddBuilding3dDialog({super.key});

  static Future<void> show(BuildContext context) {
    return showDialog<void>(
      context: context,
      builder: (_) => const AddBuilding3dDialog(),
    );
  }

  @override
  ConsumerState<AddBuilding3dDialog> createState() =>
      _AddBuilding3dDialogState();
}

class _AddBuilding3dDialogState extends ConsumerState<AddBuilding3dDialog> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _subtitleCtrl = TextEditingController();
  final _cityCtrl = TextEditingController(text: 'Ouagadougou');

  String _kind = 'building';
  String _shape = 'rect';
  double _height = 24.0;
  double _widthM = 28.0;
  double _lengthM = 34.0;
  double _rotationDeg = 0.0;
  String _color = '#E6A15C';

  double? _lat;
  double? _lon;
  bool _submitting = false;

  static const _kinds = <String, String>{
    'building': 'Bâtiment / Immeuble',
    'monument': 'Monument',
    'interchange': 'Échangeur',
    'mosque': 'Mosquée / Édifice religieux',
    'market': 'Marché / Halles',
    'stadium': 'Stade / Complexe',
    'landmark': 'Repère urbain',
  };

  static const _colors = <String, Color>{
    '#E6A15C': Color(0xFFE6A15C),
    '#D97706': Color(0xFFD97706),
    '#B45309': Color(0xFFB45309),
    '#059669': Color(0xFF059669),
    '#2563EB': Color(0xFF2563EB),
    '#64748B': Color(0xFF64748B),
    '#DC2626': Color(0xFFDC2626),
  };

  @override
  void dispose() {
    _nameCtrl.dispose();
    _subtitleCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickLocationOnMap() async {
    final picked = await AdminMapPointPickerDialog.pickPoint(
      context,
      title: 'Placer le bâtiment 3D',
      initialPoint: LatLng(_lat ?? 12.3714, _lon ?? -1.5197),
    );
    if (picked != null && mounted) {
      setState(() {
        _lat = picked.latitude;
        _lon = picked.longitude;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_lat == null || _lon == null) {
      AppSnackbar.showWarning(
        context,
        message: 'Veuillez pointer l\'emplacement exact sur la carte.',
      );
      return;
    }

    setState(() => _submitting = true);
    try {
      await ref.read(adminRepositoryProvider).createBuilding3d(
            name: _nameCtrl.text.trim(),
            subtitle: _subtitleCtrl.text.trim().isEmpty
                ? null
                : _subtitleCtrl.text.trim(),
            city: _cityCtrl.text.trim().isEmpty
                ? 'Ouagadougou'
                : _cityCtrl.text.trim(),
            kind: _kind,
            shape: _shape,
            latitude: _lat!,
            longitude: _lon!,
            height: _height,
            widthM: _widthM,
            lengthM: _lengthM,
            rotationDeg: _rotationDeg,
            color: _color,
          );
      ref.invalidate(adminBuildings3dProvider);
      ref.invalidate(monuments3dGeoJsonProvider);
      if (mounted) {
        Navigator.of(context).pop();
        AppSnackbar.showSuccess(
          context,
          title: 'Bâtiment 3D ajouté',
          message: '${_nameCtrl.text.trim()} est maintenant visible sur Faso 3D.',
        );
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Impossible d\'enregistrer le bâtiment 3D : $e',
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: const Row(
        children: [
          Icon(Icons.apartment_rounded, color: Color(0xFFD97706)),
          SizedBox(width: 8),
          Expanded(
            child: Text(
              'Déposer un Bâtiment 3D',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
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
              TextFormField(
                controller: _nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Nom du bâtiment ou monument *',
                  hintText: 'Ex: Tour administrative ZACA',
                ),
                validator: (v) =>
                    (v == null || v.trim().length < 2) ? 'Nom requis' : null,
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _subtitleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Sous-titre (optionnel)',
                  hintText: 'Ex: Ministère / Centre commercial',
                ),
              ),
              const SizedBox(height: 10),
              TextFormField(
                controller: _cityCtrl,
                decoration: const InputDecoration(labelText: 'Ville'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _kind,
                decoration: const InputDecoration(labelText: 'Type d\'édifice'),
                items: _kinds.entries
                    .map(
                      (e) => DropdownMenuItem(
                        value: e.key,
                        child: Text(e.value),
                      ),
                    )
                    .toList(),
                onChanged: (v) {
                  if (v != null) setState(() => _kind = v);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Rectangulaire'),
                      selected: _shape == 'rect',
                      onSelected: (_) => setState(() => _shape = 'rect'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ChoiceChip(
                      label: const Text('Circulaire'),
                      selected: _shape == 'circle',
                      onSelected: (_) => setState(() => _shape = 'circle'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Hauteur : ${_height.round()} m',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700),
              ),
              Slider(
                value: _height,
                min: 4,
                max: 160,
                divisions: 78,
                activeColor: AppColors.primary,
                onChanged: (v) => setState(() => _height = v),
              ),
              Text(
                'Largeur : ${_widthM.round()} m  ·  Longueur : ${_lengthM.round()} m',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Row(
                children: [
                  Expanded(
                    child: Slider(
                      value: _widthM,
                      min: 6,
                      max: 140,
                      onChanged: (v) => setState(() => _widthM = v),
                    ),
                  ),
                  Expanded(
                    child: Slider(
                      value: _lengthM,
                      min: 6,
                      max: 140,
                      onChanged: (v) => setState(() => _lengthM = v),
                    ),
                  ),
                ],
              ),
              Text(
                'Orientation : ${_rotationDeg.round()}°',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              Slider(
                value: _rotationDeg,
                min: 0,
                max: 355,
                onChanged: (v) => setState(() => _rotationDeg = v),
              ),
              const SizedBox(height: 6),
              const Text(
                'Couleur de façade 3D',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 8,
                children: _colors.entries.map((entry) {
                  final selected = _color == entry.key;
                  return GestureDetector(
                    onTap: () => setState(() => _color = entry.key),
                    child: Container(
                      width: 28,
                      height: 28,
                      decoration: BoxDecoration(
                        color: entry.value,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: selected ? Colors.black : Colors.white,
                          width: selected ? 2.5 : 1.5,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
              const SizedBox(height: 14),
              OutlinedButton.icon(
                onPressed: _pickLocationOnMap,
                icon: const Icon(Icons.pin_drop_rounded),
                label: Text(
                  _lat != null && _lon != null
                      ? 'Point : ${_lat!.toStringAsFixed(5)}, ${_lon!.toStringAsFixed(5)}'
                      : 'Pointer l\'emplacement sur la carte *',
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _submitting ? null : () => Navigator.of(context).pop(),
          child: const Text('Annuler'),
        ),
        ElevatedButton.icon(
          onPressed: _submitting ? null : _submit,
          icon: _submitting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded),
          label: const Text('Déposer en 3D'),
        ),
      ],
    );
  }
}

/// Liste et gestion (suppression) des bâtiments/monuments 3D ajoutés par l'administration.
class AdminBuildings3dSection extends ConsumerWidget {
  const AdminBuildings3dSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final buildingsAsync = ref.watch(adminBuildings3dProvider);
    return buildingsAsync.when(
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: LinearProgressIndicator(minHeight: 2),
      ),
      error: (err, _) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(
          'Impossible de charger les bâtiments 3D personnalisés ($err)',
          style: const TextStyle(color: Colors.redAccent, fontSize: 12),
        ),
      ),
      data: (items) {
        if (items.isEmpty) {
          return Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFFFFBEB),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFFDE68A)),
            ),
            child: const Row(
              children: [
                Icon(Icons.info_outline_rounded, size: 18, color: Color(0xFFD97706)),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Aucun bâtiment 3D personnalisé déposé pour le moment.',
                    style: TextStyle(fontSize: 12, color: Color(0xFF92400E)),
                  ),
                ),
              ],
            ),
          );
        }
        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: const Color(0xFFE5E7EB)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Bâtiments & Monuments 3D déposés (${items.length})',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                  color: Color(0xFF1E293B),
                ),
              ),
              const SizedBox(height: 8),
              ...items.map(
                (b) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  leading: CircleAvatar(
                    radius: 16,
                    backgroundColor: const Color(0xFFFEF3C7),
                    child: Icon(
                      b.kind == 'monument'
                          ? Icons.account_balance_rounded
                          : Icons.apartment_rounded,
                      size: 16,
                      color: const Color(0xFFD97706),
                    ),
                  ),
                  title: Text(
                    b.name,
                    style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
                  ),
                  subtitle: Text(
                    '${b.city} · ${b.kind} · ${b.height.round()} m (${b.shape})',
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, color: Colors.redAccent),
                    tooltip: 'Supprimer ce bâtiment 3D',
                    onPressed: () async {
                      try {
                        await ref.read(adminRepositoryProvider).deleteBuilding3d(b.id);
                        ref.invalidate(adminBuildings3dProvider);
                        ref.invalidate(monuments3dGeoJsonProvider);
                        if (context.mounted) {
                          AppSnackbar.showInfo(
                            context,
                            message: '${b.name} supprimé de la carte 3D.',
                          );
                        }
                      } catch (e) {
                        if (context.mounted) {
                          AppSnackbar.showError(
                            context,
                            message: 'Erreur suppression : $e',
                          );
                        }
                      }
                    },
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
