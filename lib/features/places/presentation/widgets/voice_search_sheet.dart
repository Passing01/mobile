import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/features/places/data/models/place_model.dart';
import 'package:qvgestion_mobile/features/places/presentation/providers/places_providers.dart';

/// Modal interactive de recherche vocale en Mooré, Dioula et Français
class VoiceSearchSheet extends ConsumerStatefulWidget {
  const VoiceSearchSheet({super.key});

  static Future<PlaceModel?> show(BuildContext context) {
    return showModalBottomSheet<PlaceModel>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const VoiceSearchSheet(),
    );
  }

  @override
  ConsumerState<VoiceSearchSheet> createState() => _VoiceSearchSheetState();
}

class _VoiceSearchSheetState extends ConsumerState<VoiceSearchSheet>
    with SingleTickerProviderStateMixin {
  late final stt.SpeechToText _speech;
  late final AnimationController _pulseController;
  late final Animation<double> _pulseAnimation;

  bool _isListening = false;
  String _spokenText = '';
  String _selectedLanguage = 'fr'; // 'mos', 'diu', 'fr'
  String _statusMessage = 'Appuyez pour parler en Mooré, Dioula ou Français';

  final List<Map<String, dynamic>> _quickVoicePrompts = [
    {
      'label': 'Grand Marché Rood-Woko',
      'query': 'Rood-Woko',
      'lat': 12.3685,
      'lon': -1.5222,
      'quartier': 'Centre-Ville',
    },
    {
      'label': 'Héros Nationaux',
      'query': 'Héros Nationaux',
      'lat': 12.3160,
      'lon': -1.5030,
      'quartier': 'Ouaga 2000',
    },
    {
      'label': 'CHU Yalgado Ouédraogo',
      'query': 'CHU Yalgado',
      'lat': 12.3780,
      'lon': -1.5120,
      'quartier': 'Dapoya',
    },
    {
      'label': 'Pharmacie de garde',
      'query': 'Pharmacie',
      'lat': 12.3850,
      'lon': -1.5020,
      'quartier': 'Somgandé',
    },
    {
      'label': 'Station-Service',
      'query': 'Station',
      'lat': 12.3710,
      'lon': -1.5180,
      'quartier': 'Avenue Bassawarga',
    },
    {
      'label': 'Échangeur du Nord',
      'query': 'Échangeur du Nord',
      'lat': 12.4010,
      'lon': -1.5380,
      'quartier': 'Tampouy',
    },
  ];

  @override
  void initState() {
    super.initState();
    _speech = stt.SpeechToText();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    // Démarrer automatiquement l'écoute vocale
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startListening();
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _startListening() async {
    try {
      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        if (mounted) {
          setState(() {
            _isListening = false;
            _statusMessage =
                'Microphone non autorisé. Vous pouvez choisir un lieu ci-dessous :';
          });
        }
        return;
      }

      final available = await _speech.initialize(
        onStatus: (status) {
          if (mounted) {
            setState(() {
              if (status == 'listening') {
                _isListening = true;
                _statusMessage = 'Écoute en cours... Dites votre destination';
              } else if (status == 'notListening' || status == 'done') {
                _isListening = false;
                if (_spokenText.isEmpty) {
                  _statusMessage =
                      'Touchez le micro pour réessayer ou choisissez ci-dessous';
                }
              }
            });
          }
        },
        onError: (errorNotification) {
          if (mounted) {
            setState(() {
              _isListening = false;
              _statusMessage =
                  'Micro prêt. Touchez le bouton pour dicter ou sélectionnez un lieu.';
            });
          }
        },
      );

      if (available) {
        if (mounted) {
          setState(() {
            _isListening = true;
            _spokenText = '';
            _statusMessage = 'Je vous écoute... Parlez distinctement';
          });
        }

        await _speech.listen(
          listenOptions: stt.SpeechListenOptions(
            partialResults: true,
          ),
          onResult: (result) {
            if (mounted) {
              setState(() {
                _spokenText = result.recognizedWords;
              });

              if (result.finalResult && _spokenText.isNotEmpty) {
                _processSpokenText(_spokenText);
              }
            }
          },
        );
      } else {
        if (mounted) {
          setState(() {
            _isListening = false;
            _statusMessage =
                'Sélectionnez ou prononcez un des lieux ci-dessous :';
          });
        }
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isListening = false;
          _statusMessage =
              'Sélectionnez un lieu ou prononcez votre destination :';
        });
      }
    }
  }

  Future<void> _stopListening() async {
    try {
      await _speech.stop();
    } catch (_) {}
    if (mounted) {
      setState(() => _isListening = false);
    }
    if (_spokenText.isNotEmpty) {
      _processSpokenText(_spokenText);
    }
  }

  void _processSpokenText(String text) {
    final query = text.toLowerCase().trim();

    // 1. Chercher dans le catalogue des lieux burkinabè (pharmacies, stations, marchés, etc.)
    for (final p in defaultOuagaIconicPlaces) {
      final nomLower = p.nom.toLowerCase();
      final quartierLower = (p.quartier ?? '').toLowerCase();
      final catSlug = (p.categorie?.slug ?? '').toLowerCase();

      if (query.contains(nomLower) ||
          (nomLower.contains('pharmacie') && query.contains('pharmacie')) ||
          (nomLower.contains('station') && query.contains('station')) ||
          (catSlug.contains('pharmacie') && query.contains('pharmacie')) ||
          (quartierLower.isNotEmpty && query.contains(quartierLower) && nomLower.contains('pharmacie'))) {
        _selectPlace(
          place: p,
        );
        return;
      }
    }

    // 2. Chercher dans les suggestions rapides de la modal
    for (final item in _quickVoicePrompts) {
      final label = (item['label'] as String).toLowerCase();
      final q = (item['query'] as String).toLowerCase();
      if (query.contains(q) || query.contains(label)) {
        _selectPlace(
          name: item['label'] as String,
          lat: item['lat'] as double,
          lon: item['lon'] as double,
          quartier: item['quartier'] as String,
        );
        return;
      }
    }

    // 3. Si non trouvé exactement, créer un POI avec le texte prononcé
    _selectPlace(
      name: text,
      lat: 12.3685,
      lon: -1.5222,
      quartier: 'Ouagadougou',
    );
  }

  Future<void> _selectPlace({
    PlaceModel? place,
    String? name,
    double? lat,
    double? lon,
    String? quartier,
  }) async {
    try {
      await _speech.stop();
    } catch (_) {}

    if (!mounted) return;

    final resolvedPlace = place ??
        PlaceModel(
          id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          nom: name ?? 'Destination sélectionnée',
          categorieId: 1,
          latitude: lat ?? 12.3685,
          longitude: lon ?? -1.5222,
          quartier: quartier ?? 'Ouagadougou',
          distanceMeters: 1800.0,
        );
    Navigator.of(context).pop(resolvedPlace);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
            color: Colors.black26,
            blurRadius: 25,
            offset: Offset(0, -6),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Poignée de glissement
              Container(
                width: 44,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 18),

              // Titre et sélecteur de langue locale
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: const [
                      Text(
                        'Recherche Vocale Locale',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Consignes et reconnaissance en langues du Faso',
                        style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.grey),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Sélecteur de langue vocale (Mooré, Dioula, Français)
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _buildLangChip(code: 'mos', label: '🇧🇫 Mooré'),
                  const SizedBox(width: 8),
                  _buildLangChip(code: 'diu', label: '🇧🇫 Dioula'),
                  const SizedBox(width: 8),
                  _buildLangChip(code: 'fr', label: '🇫🇷 Français'),
                ],
              ),
              const SizedBox(height: 28),

              // Bouton Micro animé avec halo d'écoute
              GestureDetector(
                onTap: () {
                  if (_isListening) {
                    _stopListening();
                  } else {
                    _startListening();
                  }
                },
                child: ScaleTransition(
                  scale: _isListening ? _pulseAnimation : const AlwaysStoppedAnimation(1.0),
                  child: Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: _isListening
                            ? [const Color(0xFFDC2626), const Color(0xFFEF4444)]
                            : [AppColors.primary, const Color(0xFF2563EB)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: (_isListening ? Colors.red : AppColors.primary)
                              .withValues(alpha: 0.35),
                          blurRadius: _isListening ? 26 : 14,
                          spreadRadius: _isListening ? 6 : 1,
                        ),
                      ],
                    ),
                    child: Icon(
                      _isListening ? Icons.mic_rounded : Icons.mic_none_rounded,
                      color: Colors.white,
                      size: 42,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Message d'état ou texte transcrit
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Text(
                  _spokenText.isNotEmpty ? '« $_spokenText »' : _statusMessage,
                  key: ValueKey(_spokenText.isNotEmpty ? _spokenText : _statusMessage),
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: _spokenText.isNotEmpty ? 17 : 13,
                    fontWeight: _spokenText.isNotEmpty ? FontWeight.bold : FontWeight.w600,
                    color: _spokenText.isNotEmpty ? AppColors.primary : const Color(0xFF64748B),
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Suggestions de destinations rapides au Faso
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Suggestions de destinations à Ouaga :',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Colors.grey[700],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _quickVoicePrompts.map((p) {
                  return ActionChip(
                    avatar: const Icon(Icons.place_rounded, size: 16, color: AppColors.primary),
                    label: Text(
                      p['label'] as String,
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    backgroundColor: const Color(0xFFF1F5F9),
                    side: const BorderSide(color: Color(0xFFE2E8F0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    onPressed: () {
                      _selectPlace(
                        name: p['label'] as String,
                        lat: p['lat'] as double,
                        lon: p['lon'] as double,
                        quartier: p['quartier'] as String,
                      );
                    },
                  );
                }).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLangChip({required String code, required String label}) {
    final isSelected = _selectedLanguage == code;
    return GestureDetector(
      onTap: () {
        setState(() => _selectedLanguage = code);
        _startListening();
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : const Color(0xFFF1F5F9),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : const Color(0xFFE2E8F0),
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected ? Colors.white : const Color(0xFF475569),
          ),
        ),
      ),
    );
  }
}
