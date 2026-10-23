import 'dart:convert';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:geolocator/geolocator.dart';
import 'package:qvgestion_mobile/core/config/env_config.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

/// Service de télémétrie trafic en temps réel alimentant le WebSocket QvGestion
class TrafficTelemetryService {
  WebSocketChannel? _channel;
  bool _isConnected = false;
  DateTime _lastSent = DateTime.fromMillisecondsSinceEpoch(0);

  /// Établit la connexion WebSocket sécurisée avec le backend
  void connect({String? customWsUrl}) {
    if (_isConnected) return;
    try {
      final wsUrl = customWsUrl ?? '${EnvConfig.wsBaseUrl}/traffic/ws';
      _channel = WebSocketChannel.connect(Uri.parse(wsUrl));
      _isConnected = true;
      AppLogger.i('📡 WebSocket trafic connecté : $wsUrl');
    } catch (e) {
      AppLogger.w('Impossible de connecter le WebSocket trafic: $e');
    }
  }

  /// Émet la position géolocalisée courante pour alimenter le calcul de fluidité
  void sendPosition(Position p) {
    if (_channel == null) {
      connect();
    }

    // Régule l'envoi pour économiser la batterie (au minimum 5s d'intervalle)
    final now = DateTime.now();
    if (now.difference(_lastSent).inSeconds < 5) {
      return;
    }
    _lastSent = now;

    try {
      final payload = {
        'lat': p.latitude,
        'lng': p.longitude,
        'speed': p.speed,
        'heading': p.heading,
        'accuracy': p.accuracy,
        'ts': now.toIso8601String(),
      };
      _channel?.sink.add(jsonEncode(payload));
    } catch (e) {
      AppLogger.w('Erreur envoi télémétrie WebSocket: $e');
    }
  }

  void disconnect() {
    _channel?.sink.close();
    _channel = null;
    _isConnected = false;
  }
}

final trafficTelemetryServiceProvider = Provider<TrafficTelemetryService>((ref) {
  final service = TrafficTelemetryService();
  ref.onDispose(() => service.disconnect());
  return service;
});
