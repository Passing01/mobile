import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qvgestion_mobile/core/debug/debug_info.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';

/// Statuts de permission et disponibilité du service de localisation (Étape 6)
enum LocationStatus {
  ok,
  denied,
  deniedForever,
  serviceOff,
}

/// Service unique de position et de suivi GPS pour toute l'application.
///
/// Responsabilités :
/// - Vérifier et demander la permission GPS selon les 4 cas standard.
/// - Diffuser le flux continu haute précision (`stream`).
/// - Filtrer les mauvais points pour la navigation (`isUsable`).
/// - Détecter la perte de signal (> 10s sans point) via un watchdog.
/// - Journaliser chaque point GPS conforme au format : `[GPS] lat, lon ±acc m, vit m/s`.
/// - Mettre à jour l'écran de télémétrie de debug (`DebugInfo`).
class LocationService {
  final _ctrl = StreamController<Position>.broadcast();
  Stream<Position> get stream => _ctrl.stream;

  StreamSubscription<Position>? _sub;
  Position? last;
  Timer? _watchdog;

  /// Notifie l'état de perte de signal GPS (> 10 secondes sans point valide)
  final ValueNotifier<bool> gpsLost = ValueNotifier<bool>(false);

  /// Dernier statut de permission obtenu
  final ValueNotifier<LocationStatus?> statusNotifier = ValueNotifier<LocationStatus?>(null);

  /// S'assure que les permissions et services sont disponibles (Étape 6)
  Future<LocationStatus> ensurePermission() async {
    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        statusNotifier.value = LocationStatus.serviceOff;
        return LocationStatus.serviceOff;
      }

      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
      }

      if (p == LocationPermission.deniedForever) {
        statusNotifier.value = LocationStatus.deniedForever;
        return LocationStatus.deniedForever;
      }

      final status = (p == LocationPermission.denied)
          ? LocationStatus.denied
          : LocationStatus.ok;

      statusNotifier.value = status;
      return status;
    } catch (e) {
      AppLogger.w('[GPS] Erreur lors de la vérification des permissions: $e');
      statusNotifier.value = LocationStatus.denied;
      return LocationStatus.denied;
    }
  }

  /// Ouvre les paramètres de l'application (pour deniedForever)
  Future<bool> openAppSettings() async {
    try {
      return await Geolocator.openAppSettings();
    } catch (e) {
      AppLogger.e('[GPS] Impossible d\'ouvrir les réglages de l\'app: $e');
      return false;
    }
  }

  /// Ouvre les paramètres système de localisation (pour serviceOff)
  Future<bool> openLocationSettings() async {
    try {
      return await Geolocator.openLocationSettings();
    } catch (e) {
      AppLogger.e('[GPS] Impossible d\'ouvrir les réglages de localisation: $e');
      return false;
    }
  }

  /// Démarre le flux GPS haute précision et le watchdog de signal
  Future<void> start() async {
    await _sub?.cancel();

    final locationSettings = kIsWeb
        ? const LocationSettings(
            accuracy: LocationAccuracy.high,
            distanceFilter: 3,
          )
        : const LocationSettings(
            accuracy: LocationAccuracy.bestForNavigation,
            distanceFilter: 3,
          );

    _sub = Geolocator.getPositionStream(
      locationSettings: locationSettings,
    ).listen(
      (p) {
        last = p;
        // Journalisation obligatoire conforme Étape 6 :
        // [GPS] latitude, longitude ± précision m, vitesse m/s
        final logMsg =
            '[GPS] ${p.latitude.toStringAsFixed(6)}, ${p.longitude.toStringAsFixed(6)} ±${p.accuracy.toStringAsFixed(0)} m, ${p.speed.toStringAsFixed(1)} m/s';
        AppLogger.i(logMsg);
        debugPrint(logMsg);

        // Alimentation de la télémétrie de débogage
        DebugInfo.instance.updateGpsFix(p);

        // Rétablissement immédiat du signal
        if (gpsLost.value) {
          gpsLost.value = false;
          AppLogger.i('📡 [GPS] Signal GPS retrouvé');
        }

        // Diffusion aux écouteurs de l'app
        _ctrl.add(p);
      },
      onError: (e) {
        AppLogger.e('⛔ [GPS] Erreur flux GPS: $e');
      },
    );

    // Watchdog : vérifie toutes les 2 secondes si le dernier point date de plus de 10 s
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 2), (_) {
      final fixAt = DebugInfo.instance.lastFixAt;
      final age = fixAt == null ? 999 : DateTime.now().difference(fixAt).inSeconds;
      final isLost = age > 10;
      if (isLost != gpsLost.value) {
        gpsLost.value = isLost;
        if (isLost) {
          AppLogger.w('⚠️ [GPS] Signal GPS perdu (aucun point reçu depuis ${age}s)');
        }
      }
    });
  }

  /// Écarte les mauvais points pour la navigation : précision > 50 m ou âge > 10 s
  bool isUsable(Position p) {
    final age = DateTime.now().difference(p.timestamp).inSeconds;
    return p.accuracy <= 50 && age <= 10;
  }

  /// Arrête le flux et le watchdog
  void stop() {
    _sub?.cancel();
    _sub = null;
    _watchdog?.cancel();
    _watchdog = null;
  }

  /// Libère les ressources
  void dispose() {
    stop();
    _ctrl.close();
    gpsLost.dispose();
    statusNotifier.dispose();
  }
}

/// Provider du service de position (Singleton dans l'arbre Riverpod)
final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(() => service.dispose());
  return service;
});

/// Provider exposant le flux de positions filtrées et exploitables
final gpsStreamProvider = StreamProvider<Position>((ref) {
  final service = ref.watch(locationServiceProvider);
  return service.stream;
});

/// Provider signalant la perte de signal GPS (> 10s)
final gpsLostProvider = NotifierProvider<GpsLostNotifier, bool>(GpsLostNotifier.new);

class GpsLostNotifier extends Notifier<bool> {
  VoidCallback? _listener;

  @override
  bool build() {
    final service = ref.watch(locationServiceProvider);
    _listener = () {
      state = service.gpsLost.value;
    };
    service.gpsLost.addListener(_listener!);
    ref.onDispose(() {
      if (_listener != null) {
        service.gpsLost.removeListener(_listener!);
      }
    });
    return service.gpsLost.value;
  }
}
