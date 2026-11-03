import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:maplibre_gl/maplibre_gl.dart';
import 'package:qvgestion_mobile/core/widgets/feedback/app_snackbar.dart';
import 'package:qvgestion_mobile/features/admin/presentation/providers/admin_providers.dart';
import 'package:qvgestion_mobile/features/admin/presentation/widgets/admin_map_point_picker_dialog.dart';

/// Dialogue pour tracer une nouvelle voie / 6-mètres / piste (GrabMaps style FASO NAV)
class TraceRoadDialog extends ConsumerStatefulWidget {
  final double? initialLat;
  final double? initialLon;

  const TraceRoadDialog({
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
      builder: (ctx) => TraceRoadDialog(
        initialLat: initialLat,
        initialLon: initialLon,
      ),
    );
  }

  @override
  ConsumerState<TraceRoadDialog> createState() => _TraceRoadDialogState();
}

class _TraceRoadDialogState extends ConsumerState<TraceRoadDialog> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameCtrl;
  late final TextEditingController _startLatCtrl;
  late final TextEditingController _startLonCtrl;
  late final TextEditingController _endLatCtrl;
  late final TextEditingController _endLonCtrl;

  String _roadType = 'residential';
  String _surface = 'unpaved';
  int _widthMeters = 6;
  final bool _isOneWay = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final baseLat = widget.initialLat ?? 12.3680;
    final baseLon = widget.initialLon ?? -1.5270;

    _nameCtrl = TextEditingController(text: 'Voie 6-mètres ');
    _startLatCtrl = TextEditingController(text: baseLat.toStringAsFixed(6));
    _startLonCtrl = TextEditingController(text: baseLon.toStringAsFixed(6));
    _endLatCtrl = TextEditingController(text: (baseLat + 0.0025).toStringAsFixed(6));
    _endLonCtrl = TextEditingController(text: (baseLon + 0.0018).toStringAsFixed(6));
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _startLatCtrl.dispose();
    _startLonCtrl.dispose();
    _endLatCtrl.dispose();
    _endLonCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final startLat = double.tryParse(_startLatCtrl.text.trim());
    final startLon = double.tryParse(_startLonCtrl.text.trim());
    final endLat = double.tryParse(_endLatCtrl.text.trim());
    final endLon = double.tryParse(_endLonCtrl.text.trim());

    if (startLat == null || startLon == null || endLat == null || endLon == null) {
      AppSnackbar.showError(context, message: 'Coordonnées de tracé invalides');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final repo = ref.read(adminRepositoryProvider);
      final coords = [
        {'lat': startLat, 'lon': startLon},
        {'lat': endLat, 'lon': endLon},
      ];

      await repo.traceRoad(
        name: _nameCtrl.text.trim(),
        roadType: _roadType,
        surface: _surface,
        coordinates: coords,
        widthMeters: _widthMeters,
        isOneWay: _isOneWay,
      );

      if (mounted) {
        AppSnackbar.showSuccess(
          context,
          message: 'Voie tracée avec succès et injectée dans le réseau !',
        );
        Navigator.of(context).pop(true);
      }
    } catch (e) {
      if (mounted) {
        AppSnackbar.showError(
          context,
          message: 'Erreur lors du traçage de la voie : $e',
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
              color: const Color(0xFFE0E7FF),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.edit_road_rounded, color: Color(0xFF4338CA), size: 24),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Tracer une Voie / 6-Mètres',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Éditeur souverain • Réseau national',
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
                  labelText: 'Nom de la voie / repère *',
                  hintText: 'ex: 6-mètres Cissin vers Échangeur',
                  prefixIcon: Icon(Icons.add_road_rounded, size: 20),
                ),
                validator: (val) =>
                    (val == null || val.trim().isEmpty) ? 'Requis' : null,
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _roadType,
                decoration: const InputDecoration(
                  labelText: 'Type de voirie',
                  prefixIcon: Icon(Icons.category_rounded, size: 20),
                ),
                items: const [
                  DropdownMenuItem(value: 'residential', child: Text('Rue résidentielle / 6-mètres')),
                  DropdownMenuItem(value: 'track', child: Text('Piste rurale / terre')),
                  DropdownMenuItem(value: 'service', child: Text('Voie de desserte / maquis')),
                  DropdownMenuItem(value: 'path', child: Text('Sentier deux-roues / piéton')),
                ],
                onChanged: (val) {
                  if (val != null) setState(() => _roadType = val);
                },
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      initialValue: _surface,
                      decoration: const InputDecoration(labelText: 'Revêtement'),
                      items: const [
                        DropdownMenuItem(value: 'unpaved', child: Text('Terre / Latérite')),
                        DropdownMenuItem(value: 'paved', child: Text('Goudronné')),
                        DropdownMenuItem(value: 'gravel', child: Text('Gravillon')),
                        DropdownMenuItem(value: 'sand', child: Text('Sable')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _surface = val);
                      },
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: DropdownButtonFormField<int>(
                      initialValue: _widthMeters,
                      decoration: const InputDecoration(labelText: 'Largeur'),
                      items: const [
                        DropdownMenuItem(value: 4, child: Text('4 m')),
                        DropdownMenuItem(value: 6, child: Text('6 m (Standard)')),
                        DropdownMenuItem(value: 8, child: Text('8 m')),
                        DropdownMenuItem(value: 12, child: Text('12 m (Boulevard)')),
                      ],
                      onChanged: (val) {
                        if (val != null) setState(() => _widthMeters = val);
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Point de Départ GPS :',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  TextButton.icon(
                    key: const Key('trace_road_pick_start_map_button'),
                    icon: const Icon(Icons.map_rounded, size: 14),
                    label: const Text('Pointer sur carte 📍', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF4338CA),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final curLat = double.tryParse(_startLatCtrl.text.trim()) ??
                          widget.initialLat ??
                          12.3680;
                      final curLon = double.tryParse(_startLonCtrl.text.trim()) ??
                          widget.initialLon ??
                          -1.5270;
                      final picked = await AdminMapPointPickerDialog.pickPoint(
                        context,
                        initialPoint: LatLng(curLat, curLon),
                        title: 'Point de Départ de la Voie',
                        subtitle: 'Touchez l\'intersection ou le début du tracé',
                        confirmLabel: 'Définir le point de départ',
                        confirmIcon: Icons.play_arrow_rounded,
                        themeColor: const Color(0xFF4338CA),
                      );
                      if (picked != null) {
                        setState(() {
                          _startLatCtrl.text = picked.latitude.toStringAsFixed(6);
                          _startLonCtrl.text = picked.longitude.toStringAsFixed(6);
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _startLatCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Lat Début'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _startLonCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(labelText: 'Lon Début'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Point d\'Arrivée GPS :',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                  TextButton.icon(
                    key: const Key('trace_road_pick_end_map_button'),
                    icon: const Icon(Icons.map_rounded, size: 14),
                    label: const Text('Pointer sur carte 📍', style: TextStyle(fontSize: 11)),
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF059669),
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      visualDensity: VisualDensity.compact,
                    ),
                    onPressed: () async {
                      final curLat = double.tryParse(_endLatCtrl.text.trim()) ??
                          widget.initialLat ??
                          12.3705;
                      final curLon = double.tryParse(_endLonCtrl.text.trim()) ??
                          widget.initialLon ??
                          -1.5252;
                      final picked = await AdminMapPointPickerDialog.pickPoint(
                        context,
                        initialPoint: LatLng(curLat, curLon),
                        title: 'Point d\'Arrivée de la Voie',
                        subtitle: 'Touchez le point de fin du tracé',
                        confirmLabel: 'Définir le point d\'arrivée',
                        confirmIcon: Icons.flag_rounded,
                        themeColor: const Color(0xFF059669),
                      );
                      if (picked != null) {
                        setState(() {
                          _endLatCtrl.text = picked.latitude.toStringAsFixed(6);
                          _endLonCtrl.text = picked.longitude.toStringAsFixed(6);
                        });
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _endLatCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(labelText: 'Lat Fin'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _endLonCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
                      decoration: const InputDecoration(labelText: 'Lon Fin'),
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
              : const Icon(Icons.save_rounded, size: 18),
          label: const Text('Valider le Tracé'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF4338CA),
            foregroundColor: Colors.white,
          ),
        ),
      ],
    );
  }
}

