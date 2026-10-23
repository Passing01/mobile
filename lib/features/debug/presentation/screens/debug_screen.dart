import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geolocator/geolocator.dart';
import 'package:dio/dio.dart';
import 'package:qvgestion_mobile/core/config/app_config.dart';
import 'package:qvgestion_mobile/core/config/app_constants.dart';
import 'package:qvgestion_mobile/core/config/env_config.dart';
import 'package:qvgestion_mobile/core/debug/debug_info.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';

/// Écran de Debug officiel FASO NAV (Étape 0)
/// Caché derrière 7 touchers sur le numéro de version de l'application.
/// Affiche les 8 rubriques indispensables et permet d'exporter le journal d'exécution.
class DebugScreen extends StatefulWidget {
  const DebugScreen({super.key});

  @override
  State<DebugScreen> createState() => _DebugScreenState();
}

class _DebugScreenState extends State<DebugScreen> {
  final DebugInfo _debugInfo = DebugInfo.instance;
  bool _isCheckingNetwork = false;
  bool _isFixingGps = false;

  @override
  void initState() {
    super.initState();
    _debugInfo.addListener(_onDebugInfoChanged);
    _checkNetworkHealth();
  }

  @override
  void dispose() {
    _debugInfo.removeListener(_onDebugInfoChanged);
    super.dispose();
  }

  void _onDebugInfoChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _checkNetworkHealth() async {
    setState(() => _isCheckingNetwork = true);
    final stopwatch = Stopwatch()..start();
    try {
      final dio = Dio(
        BaseOptions(
          connectTimeout: const Duration(seconds: 5),
          receiveTimeout: const Duration(seconds: 5),
        ),
      );
      final url = EnvConfig.apiBaseUrl.replaceFirst('/api/v1', '/');
      final res = await dio.get(url);
      stopwatch.stop();
      _debugInfo.updateNetworkStatus(
        'Connecté • HTTP ${res.statusCode} (${stopwatch.elapsedMilliseconds} ms)',
      );
      AppLogger.info(
        'Vérification réseau réussie vers $url : HTTP ${res.statusCode} (${stopwatch.elapsedMilliseconds} ms)',
        tag: 'DebugScreen',
      );
    } catch (e) {
      stopwatch.stop();
      _debugInfo.updateNetworkStatus('Échec connexion : $e');
      AppLogger.error(
        'Échec vérification réseau',
        error: e,
        tag: 'DebugScreen',
      );
    } finally {
      if (mounted) setState(() => _isCheckingNetwork = false);
    }
  }

  Future<void> _requestGpsFix() async {
    setState(() => _isFixingGps = true);
    try {
      final permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        await Geolocator.requestPermission();
      }
      final position = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(accuracy: LocationAccuracy.best),
      );
      _debugInfo.updateGpsFix(position);
      AppLogger.info(
        'Point GPS rafraîchi : ${position.latitude.toStringAsFixed(6)}, ${position.longitude.toStringAsFixed(6)} (±${position.accuracy.toStringAsFixed(1)}m)',
        tag: 'GPS',
      );
    } catch (e) {
      AppLogger.error('Impossible d\'obtenir le point GPS', error: e, tag: 'GPS');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur GPS: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _isFixingGps = false);
    }
  }

  void _exportJournal() {
    final exportText = AppLogger.exportLogs();
    Clipboard.setData(ClipboardData(text: exportText));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('✅ Journal copié dans le presse-papiers avec succès !'),
        backgroundColor: Color(0xFF059669),
        behavior: SnackBarBehavior.floating,
      ),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) => Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Extrait du Journal Exporté',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
              const Divider(),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  child: SelectableText(
                    exportText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                      color: Color(0xFF1E293B),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final fix = _debugInfo.lastFix;
    final fixAge = _debugInfo.lastFixAt != null
        ? '${DateTime.now().difference(_debugInfo.lastFixAt!).inSeconds} s'
        : 'Aucun';

    return Scaffold(
      backgroundColor: const Color(0xFFF1F5F9),
      appBar: AppBar(
        title: const Text(
          'FASO NAV — Console de Debug',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        backgroundColor: const Color(0xFF0F172A),
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Tester le réseau',
            onPressed: _isCheckingNetwork ? null : _checkNetworkHealth,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(14),
        children: [
          // Bandeau Mode d'exécution
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: AppConfig.testMode
                  ? const Color(0xFFFEF3C7) // Jaune test
                  : const Color(0xFFDCFCE7), // Vert prod
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: AppConfig.testMode
                    ? const Color(0xFFF59E0B)
                    : const Color(0xFF10B981),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  AppConfig.testMode ? Icons.bug_report : Icons.verified_user,
                  color: AppConfig.testMode
                      ? const Color(0xFFB45309)
                      : const Color(0xFF047857),
                  size: 20,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    AppConfig.testMode
                        ? 'MODE TEST ACTIF (Données de test & backend de test)'
                        : 'MODE NORMAL / PRODUCTION (Données réelles)',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                      color: AppConfig.testMode
                          ? const Color(0xFF92400E)
                          : const Color(0xFF065F46),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),

          // 1. Version de l'app & Backend
          _buildDebugCard(
            title: '1. Version & Backend',
            icon: Icons.info_outline,
            children: [
              _buildRow('Version App', AppConstants.appVersion),
              _buildRow('Mode Test (AppConfig.testMode)', AppConfig.testMode ? 'OUI (Test)' : 'NON (Production)'),
              _buildRow('URL Backend Active', EnvConfig.apiBaseUrl),
              _buildRow('Environnement EnvConfig', EnvConfig.environment.name.toUpperCase()),
            ],
          ),
          const SizedBox(height: 10),

          // 2. État du réseau
          _buildDebugCard(
            title: '2. État du Réseau',
            icon: Icons.wifi,
            trailing: _isCheckingNetwork
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton(
                    onPressed: _checkNetworkHealth,
                    child: const Text('Tester Ping', style: TextStyle(fontSize: 12)),
                  ),
            children: [
              _buildRow('Statut Connectivité', _debugInfo.networkStatus),
            ],
          ),
          const SizedBox(height: 10),

          // 3. Position GPS réelle
          _buildDebugCard(
            title: '3. Position GPS Réelle',
            icon: Icons.my_location,
            trailing: _isFixingGps
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : TextButton.icon(
                    onPressed: _requestGpsFix,
                    icon: const Icon(Icons.gps_fixed, size: 14),
                    label: const Text('Acquérir Fix', style: TextStyle(fontSize: 12)),
                  ),
            children: [
              _buildRow(
                'Latitude',
                fix != null ? fix.latitude.toStringAsFixed(6) : 'Non acquise',
              ),
              _buildRow(
                'Longitude',
                fix != null ? fix.longitude.toStringAsFixed(6) : 'Non acquise',
              ),
              _buildRow(
                'Précision',
                fix != null ? '±${fix.accuracy.toStringAsFixed(1)} m' : '-',
              ),
              _buildRow('Âge du dernier point', fixAge),
            ],
          ),
          const SizedBox(height: 10),

          // 4. Destination
          _buildDebugCard(
            title: '4. Destination Active',
            icon: Icons.flag_rounded,
            children: [
              _buildRow(
                'Latitude',
                _debugInfo.destination != null
                    ? _debugInfo.destination!.latitude.toStringAsFixed(6)
                    : 'Aucune',
              ),
              _buildRow(
                'Longitude',
                _debugInfo.destination != null
                    ? _debugInfo.destination!.longitude.toStringAsFixed(6)
                    : 'Aucune',
              ),
              _buildRow(
                'Source de la Destination',
                _debugInfo.destinationSource,
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 5. Itinéraire
          _buildDebugCard(
            title: '5. Itinéraire Actif',
            icon: Icons.alt_route_rounded,
            children: [
              _buildRow('Nombre de Points', '${_debugInfo.routePoints}'),
              _buildRow(
                'Distance Totale',
                _debugInfo.routeDistanceM > 0
                    ? '${(_debugInfo.routeDistanceM / 1000).toStringAsFixed(2)} km (${_debugInfo.routeDistanceM.toStringAsFixed(0)} m)'
                    : '0 m',
              ),
              _buildRow(
                'Durée Estimée',
                _debugInfo.routeDurationS > 0
                    ? '${(_debugInfo.routeDurationS / 60).toStringAsFixed(1)} min'
                    : '0 s',
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 6. Test d'arrivée
          _buildDebugCard(
            title: '6. Test d\'Arrivée',
            icon: Icons.sports_score_rounded,
            children: [
              _buildRow(
                'Distance à l\'arrivée',
                _debugInfo.distanceToArrivalM != null
                    ? '${_debugInfo.distanceToArrivalM!.toStringAsFixed(1)} m'
                    : 'N/A',
              ),
              _buildRow(
                'Seuil d\'arrivée configuré',
                '${_debugInfo.arrivalThresholdM.toStringAsFixed(0)} m',
              ),
            ],
          ),
          const SizedBox(height: 10),

          // 7. Dernière erreur d'API
          _buildDebugCard(
            title: '7. Dernière Erreur d\'API',
            icon: Icons.warning_rounded,
            children: [
              _buildRow(
                'Erreur',
                _debugInfo.lastApiError ?? 'Aucune erreur enregistrée',
                textColor: _debugInfo.lastApiError != null
                    ? const Color(0xFFDC2626)
                    : const Color(0xFF16A34A),
              ),
              if (_debugInfo.lastApiErrorAt != null)
                _buildRow(
                  'Survenue à',
                  _debugInfo.lastApiErrorAt!.toIso8601String(),
                ),
            ],
          ),
          const SizedBox(height: 16),

          // 8. Bouton Exporter le journal
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _exportJournal,
              icon: const Icon(Icons.download_rounded),
              label: const Text(
                '8. EXPORTER LE JOURNAL D\'EXÉCUTION',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0F172A),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  Widget _buildDebugCard({
    required String title,
    required IconData icon,
    required List<Widget> children,
    Widget? trailing,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: const Color(0xFF334155)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ),
                ?trailing,
              ],
            ),
            const Divider(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildRow(String label, String value, {Color? textColor}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF64748B),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: textColor ?? const Color(0xFF0F172A),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
