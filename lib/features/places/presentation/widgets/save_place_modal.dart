import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';

/// Modal permettant à un utilisateur connecté de créer ou enregistrer sa position
/// avec un nom personnalisé, une catégorie et une description (style Google Maps),
/// et de la partager directement.
class SavePlaceModal extends ConsumerStatefulWidget {
  final double latitude;
  final double longitude;
  final String? initialName;
  final String? initialCategory;

  const SavePlaceModal({
    super.key,
    required this.latitude,
    required this.longitude,
    this.initialName,
    this.initialCategory,
  });

  static Future<PlaceModel?> show(
    BuildContext context, {
    required double latitude,
    required double longitude,
    String? initialName,
    String? initialCategory,
  }) {
    return showModalBottomSheet<PlaceModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SavePlaceModal(
          latitude: latitude,
          longitude: longitude,
          initialName: initialName,
          initialCategory: initialCategory,
        ),
      ),
    );
  }

  @override
  ConsumerState<SavePlaceModal> createState() => _SavePlaceModalState();
}

class _SavePlaceModalState extends ConsumerState<SavePlaceModal> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _descController;
  late final TextEditingController _addressController;
  String _selectedCategory = 'commerce';
  bool _isLoading = false;

  final List<Map<String, dynamic>> _categories = const [
    {'slug': 'commerce', 'nom': 'Boutique / Commerce', 'icon': Icons.storefront_rounded, 'id': 6},
    {'slug': 'maquis-restaurant', 'nom': 'Restaurant / Maquis', 'icon': Icons.restaurant_rounded, 'id': 3},
    {'slug': 'domicile', 'nom': 'Domicile / Résidence', 'icon': Icons.home_rounded, 'id': 7},
    {'slug': 'bureau', 'nom': 'Bureau / Entreprise', 'icon': Icons.business_rounded, 'id': 5},
    {'slug': 'sante', 'nom': 'Santé / Pharmacie', 'icon': Icons.local_hospital_rounded, 'id': 1},
    {'slug': 'autre', 'nom': 'Autre lieu', 'icon': Icons.place_rounded, 'id': 8},
  ];

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName ?? '');
    _descController = TextEditingController();
    _addressController = TextEditingController();
    if (widget.initialCategory != null) {
      _selectedCategory = widget.initialCategory!;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descController.dispose();
    _addressController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    final repo = ref.read(placesRepositoryProvider);
    final selectedCatObj = _categories.firstWhere(
      (c) => c['slug'] == _selectedCategory,
      orElse: () => _categories.first,
    );

    try {
      final payload = {
        'nom': _nameController.text.trim(),
        'description': _descController.text.trim().isEmpty ? null : _descController.text.trim(),
        'adresse': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'latitude': widget.latitude,
        'longitude': widget.longitude,
        'categorie_id': selectedCatObj['id'],
        'ville': 'Ouagadougou',
        'is_anchor': false,
      };

      final createdPlace = await repo.createPlace(payload);
      AppLogger.i('Lieu créé avec succès: ${createdPlace.nom}');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lieu "${createdPlace.nom}" enregistré avec succès !'),
            backgroundColor: const Color(0xFF0F766E),
          ),
        );
        Navigator.of(context).pop(createdPlace);
      }
    } catch (e) {
      AppLogger.e('Erreur enregistrement lieu: $e');
      if (mounted) {
        // En mode hors-ligne ou erreur backend, créer le modèle local
        final localPlace = PlaceModel(
          id: DateTime.now().millisecondsSinceEpoch,
          nom: _nameController.text.trim(),
          description: _descController.text.trim(),
          adresse: _addressController.text.trim(),
          categorieId: selectedCatObj['id'] as int,
          latitude: widget.latitude,
          longitude: widget.longitude,
          ville: 'Ouagadougou',
        );

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Lieu "${localPlace.nom}" enregistré localement.'),
            backgroundColor: const Color(0xFF0F766E),
          ),
        );
        Navigator.of(context).pop(localPlace);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _shareLocation() {
    final name = _nameController.text.trim().isEmpty ? 'Ma position' : _nameController.text.trim();
    final text = '📍 $name\n'
        'Coordonnées : ${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}\n'
        'https://maps.google.com/?q=${widget.latitude},${widget.longitude}';
    SharePlus.instance.share(
      ShareParams(
        text: text,
        subject: 'Partage de position : $name',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
      child: Form(
        key: _formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Poignée
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[300],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // En-tête
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDFA),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: const Icon(Icons.add_location_alt_rounded, color: Color(0xFF0F766E), size: 24),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Enregistrer ce lieu',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                        ),
                        Text(
                          'Ajouter à mes adresses & partager',
                          style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Coordonnées GPS
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE2E8F0)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.my_location_rounded, size: 16, color: Color(0xFF0F766E)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'GPS : ${widget.latitude.toStringAsFixed(5)}, ${widget.longitude.toStringAsFixed(5)}',
                        style: const TextStyle(fontSize: 12, color: Color(0xFF475569), fontWeight: FontWeight.w500),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: _shareLocation,
                      icon: const Icon(Icons.share_rounded, size: 15, color: Color(0xFF0F766E)),
                      label: const Text('Partager', style: TextStyle(fontSize: 12, color: Color(0xFF0F766E), fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Champ Nom du lieu
              TextFormField(
                controller: _nameController,
                autofocus: true,
                decoration: InputDecoration(
                  labelText: 'Nom du lieu *',
                  hintText: 'Ex: Mon domicile, Boutique Alpha...',
                  prefixIcon: const Icon(Icons.edit_location_alt_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) {
                    return 'Veuillez saisir un nom pour ce lieu';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 12),

              // Sélecteur Catégorie
              DropdownButtonFormField<String>(
                initialValue: _selectedCategory,
                decoration: InputDecoration(
                  labelText: 'Catégorie',
                  prefixIcon: const Icon(Icons.category_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
                items: _categories.map((c) {
                  return DropdownMenuItem<String>(
                    value: c['slug'] as String,
                    child: Row(
                      children: [
                        Icon(c['icon'] as IconData, size: 18, color: const Color(0xFF0F766E)),
                        const SizedBox(width: 8),
                        Text(c['nom'] as String, style: const TextStyle(fontSize: 13)),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => _selectedCategory = val);
                },
              ),
              const SizedBox(height: 12),

              // Champ Description / Quartier
              TextFormField(
                controller: _descController,
                decoration: InputDecoration(
                  labelText: 'Description / Repère (optionnel)',
                  hintText: 'Ex: Près du goudron, portail bleu...',
                  prefixIcon: const Icon(Icons.notes_rounded, size: 20),
                  filled: true,
                  fillColor: const Color(0xFFF8FAFC),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                ),
              ),
              const SizedBox(height: 20),

              // Boutons d'action
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _shareLocation,
                      icon: const Icon(Icons.share_rounded, size: 18),
                      label: const Text('Partager'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        side: const BorderSide(color: Color(0xFF0F766E)),
                        foregroundColor: const Color(0xFF0F766E),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton.icon(
                      onPressed: _isLoading ? null : _submit,
                      icon: _isLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Icon(Icons.check_rounded, size: 20),
                      label: Text(
                        _isLoading ? 'Enregistrement...' : 'Enregistrer le lieu',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF0F766E),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
