import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:qvgestion_mobile/core/config/app_config.dart';
import 'package:qvgestion_mobile/core/config/app_constants.dart';
import 'package:qvgestion_mobile/core/theme/app_colors.dart';
import 'package:qvgestion_mobile/features/auth/presentation/providers/auth_notifier.dart';
import 'package:qvgestion_mobile/features/auth/presentation/widgets/auth_modal_sheet.dart';
import 'package:qvgestion_mobile/features/auth/presentation/widgets/language_selector_chips.dart';
import 'package:qvgestion_mobile/features/debug/presentation/screens/debug_screen.dart';

/// Onglet 4 officiel : Profil, Préférences Linguistiques & Sécurité
class AccountScreen extends ConsumerWidget {
  const AccountScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authNotifierProvider);
    final user = authState.user;
    final isAuth = authState.isAuthenticated;

    final displayName = user?.nom ?? 'Rasmané Ouedraogo';
    final displayPhone = user?.telephone ?? '+22670223344';
    final currentLang = user?.languePreferee ?? 'mos';

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text(
          'Mon Profil Faso Nav',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Carte de profil
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.04),
                  blurRadius: 10,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.primary,
                  child: Text(
                    displayName.isNotEmpty ? displayName[0] : 'U',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF111827),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        displayPhone,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF6B7280),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEFF6FF),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          user?.role.toUpperCase() ?? 'CONDUCTEUR DEUX-ROUES',
                          style: const TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Préférences linguistiques (Mooré, Dioula, Français)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Langue des Consignes Vocales',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Consignes de navigation lues avec accentuation et repères locaux.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                LanguageSelectorChips(
                  selectedCode: currentLang,
                  onSelected: (newLang) {
                    ref
                        .read(authNotifierProvider.notifier)
                        .updateLanguage(newLang);
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Statistiques de mobilité
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Statistiques de Déplacement Deux-Roues',
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: const [
                    _StatCol(value: '148 km', label: 'Parcourus'),
                    _StatCol(value: '22', label: 'Trajets optimisés'),
                    _StatCol(value: '4.2 kg', label: 'CO2 évité'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Bouton Connexion / Déconnexion
          OutlinedButton.icon(
            onPressed: () {
              if (isAuth) {
                ref.read(authNotifierProvider.notifier).logout();
              } else {
                AuthModalSheet.show(context);
              }
            },
            icon: Icon(
              isAuth ? Icons.logout_rounded : Icons.login_rounded,
              color: isAuth ? Colors.red : AppColors.primary,
            ),
            label: Text(
              isAuth ? 'Se déconnecter' : 'Connexion / Inscription',
              style: TextStyle(
                color: isAuth ? Colors.red : AppColors.primary,
                fontWeight: FontWeight.bold,
              ),
            ),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              side: BorderSide(
                color: isAuth ? Colors.red.shade200 : AppColors.primary,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
          const SizedBox(height: 12),
          const AppVersionFooter(),
        ],
      ),
    );
  }
}

class AppVersionFooter extends StatefulWidget {
  const AppVersionFooter({super.key});

  @override
  State<AppVersionFooter> createState() => _AppVersionFooterState();
}

class _AppVersionFooterState extends State<AppVersionFooter> {
  int _taps = 0;
  DateTime? _lastTap;

  void _onTap() {
    final now = DateTime.now();
    if (_lastTap == null || now.difference(_lastTap!) > const Duration(seconds: 2)) {
      _taps = 1;
    } else {
      _taps++;
    }
    _lastTap = now;

    if (_taps >= 4 && _taps < 7) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Plus que ${7 - _taps} appui(s) pour ouvrir la console de debug'),
          duration: const Duration(milliseconds: 800),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } else if (_taps >= 7) {
      _taps = 0;
      HapticFeedback.mediumImpact();
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const DebugScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: _onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Text(
              'FASO NAV v${AppConstants.appVersion}',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF94A3B8),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Mobilité Urbaine Ouagadougou • ${AppConfig.testMode ? "MODE TEST ACTIF" : "PRODUCTION"}',
              style: TextStyle(
                fontSize: 10,
                color: AppConfig.testMode ? Colors.amber.shade800 : const Color(0xFFCBD5E1),
                fontWeight: AppConfig.testMode ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCol extends StatelessWidget {
  final String value;
  final String label;

  const _StatCol({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: AppColors.primary,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(fontSize: 11, color: Colors.grey),
        ),
      ],
    );
  }
}
