import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:qvgestion_mobile/core/utils/app_logger.dart';

/// Résultat structuré d'un lien ou texte de localisation reçu depuis WhatsApp, Web ou SMS
class ParsedLocationLink {
  final double? latitude;
  final double? longitude;
  final String? label;
  final String? searchQuery;
  final String rawInput;

  const ParsedLocationLink({
    this.latitude,
    this.longitude,
    this.label,
    this.searchQuery,
    required this.rawInput,
  });

  bool get hasCoordinates =>
      latitude != null &&
      longitude != null &&
      latitude!.isFinite &&
      longitude!.isFinite &&
      latitude!.abs() <= 90.0 &&
      longitude!.abs() <= 180.0 &&
      !(latitude == 0.0 && longitude == 0.0);
}

/// Analyseur haute précision pour tous les formats de partage de localisation :
/// - WhatsApp (`geo:lat,lon?q=...`, texte partagé, liens Google Maps)
/// - Google Maps (`!3d..!4d..`, `@lat,lon`, `?q=lat,lon`, `?query=lat,lon`, liens courts `maps.app.goo.gl`)
/// - OpenStreetMap (`?mlat=..&mlon=..`, `#map=z/lat/lon`)
/// - Apple Maps (`?ll=lat,lon`)
/// - Schéma personnalisé `fasonav://open?lat=..&lon=..&name=..`
/// - Coordonnées brutes dans un message texte (`12.3685, -1.5271`)
class LocationLinkParser {
  static final RegExp _urlInTextRegex = RegExp(
    r'(https?://[^\s]+|geo:[^\s]+|fasonav://[^\s]+)',
    caseSensitive: false,
  );

  static final RegExp _googleExactPinRegex = RegExp(
    r'!3d(-?\d+(?:\.\d+)?)!4d(-?\d+(?:\.\d+)?)',
  );

  static final RegExp _googleAtRegex = RegExp(
    r'@(-?\d+(?:\.\d+)?),(-?\d+(?:\.\d+)?)',
  );

  static final RegExp _coordPairRegex = RegExp(
    r'(-?\d{1,2}\.\d{3,})\s*,\s*(-?\d{1,3}\.\d{3,})',
  );

  static final RegExp _osmHashRegex = RegExp(
    r'#map=\d+/(-?\d+(?:\.\d+)?)/(-?\d+(?:\.\d+)?)',
  );

  static final RegExp _parenLabelRegex = RegExp(r'\(([^)]+)\)$');

  static bool isShortMapUrl(String input) {
    final lower = input.toLowerCase();
    return lower.contains('maps.app.goo.gl/') ||
        lower.contains('goo.gl/maps/') ||
        lower.contains('osm.org/go/');
  }

  /// Résout d'éventuelles redirections de liens courts (ex: WhatsApp -> maps.app.goo.gl)
  /// avant d'extraire les coordonnées exactes.
  static Future<ParsedLocationLink?> resolveAndParse(String rawInput) async {
    final trimmed = rawInput.trim();
    if (trimmed.isEmpty) return null;

    var candidate = trimmed;
    final urlMatch = _urlInTextRegex.firstMatch(trimmed);
    if (urlMatch != null) {
      final extractedUrl = urlMatch.group(0)!;
      if (isShortMapUrl(extractedUrl)) {
        final resolved = await _resolveShortUrl(extractedUrl);
        if (resolved != null && resolved.isNotEmpty) {
          candidate = resolved;
        }
      }
    }

    return parse(candidate, originalRaw: trimmed);
  }

  static Future<String?> _resolveShortUrl(String shortUrl) async {
    final client = HttpClient()..connectionTimeout = const Duration(seconds: 6);
    try {
      var currentUri = Uri.parse(shortUrl);
      for (var i = 0; i < 5; i++) {
        final req = await client.getUrl(currentUri);
        req.followRedirects = false;
        req.headers.set(HttpHeaders.userAgentHeader, 'FasoNav/1.0');
        final res = await req.close().timeout(const Duration(seconds: 6));
        await res.drain<void>();
        final loc = res.headers.value(HttpHeaders.locationHeader);
        if (loc == null || loc.isEmpty) {
          return currentUri.toString();
        }
        currentUri = currentUri.resolve(loc);
        if (!isShortMapUrl(currentUri.toString())) {
          return currentUri.toString();
        }
      }
      return currentUri.toString();
    } catch (e) {
      AppLogger.d('Résolution lien court impossible ($e)');
      return null;
    } finally {
      client.close(force: true);
    }
  }

  /// Analyse synchrone d'un lien ou d'un texte partagé.
  static ParsedLocationLink? parse(String input, {String? originalRaw}) {
    final trimmed = input.trim();
    if (trimmed.isEmpty) return null;
    final rawOut = originalRaw ?? trimmed;

    // Si le texte partagé (WhatsApp) contient une URL, l'analyser prioritairement
    final embeddedUrlMatch = _urlInTextRegex.firstMatch(trimmed);
    final targetStr = embeddedUrlMatch != null
        ? embeddedUrlMatch.group(0)!
        : trimmed;

    // 1. Schéma geo:lat,lon?q=...
    if (targetStr.toLowerCase().startsWith('geo:')) {
      return _parseGeoUri(targetStr, rawOut);
    }

    final uri = Uri.tryParse(targetStr);
    if (uri != null &&
        (uri.scheme == 'http' ||
            uri.scheme == 'https' ||
            uri.scheme == 'fasonav')) {
      // 2. Priorité maximale : épingle exacte Google Maps !3dLAT!4dLON
      final exactPin = _googleExactPinRegex.firstMatch(targetStr);
      if (exactPin != null) {
        final lat = double.tryParse(exactPin.group(1)!);
        final lon = double.tryParse(exactPin.group(2)!);
        if (_validPair(lat, lon)) {
          return ParsedLocationLink(
            latitude: lat,
            longitude: lon,
            label: _extractPlaceLabelFromUri(uri),
            rawInput: rawOut,
          );
        }
      }

      // 3. Paramètres query standard (lat/lon, mlat/mlon, q, query, ll, daddr)
      final qp = uri.queryParameters;
      final pLat = double.tryParse(qp['lat'] ?? qp['mlat'] ?? '');
      final pLon = double.tryParse(qp['lon'] ?? qp['lng'] ?? qp['mlon'] ?? '');
      if (_validPair(pLat, pLon)) {
        return ParsedLocationLink(
          latitude: pLat,
          longitude: pLon,
          label: _cleanLabel(qp['name'] ?? qp['q'] ?? qp['label']),
          rawInput: rawOut,
        );
      }

      for (final key in const ['q', 'query', 'll', 'daddr', 'center']) {
        final val = qp[key];
        if (val != null && val.isNotEmpty) {
          final pair = _extractCoordPair(val);
          if (pair != null) {
            final labelMatch = _parenLabelRegex.firstMatch(val);
            final label = labelMatch != null
                ? _cleanLabel(labelMatch.group(1))
                : _extractPlaceLabelFromUri(uri);
            return ParsedLocationLink(
              latitude: pair.$1,
              longitude: pair.$2,
              label: label,
              rawInput: rawOut,
            );
          }
        }
      }

      // 4. Google Maps @lat,lon,zoom
      final atMatch = _googleAtRegex.firstMatch(targetStr);
      if (atMatch != null) {
        final lat = double.tryParse(atMatch.group(1)!);
        final lon = double.tryParse(atMatch.group(2)!);
        if (_validPair(lat, lon)) {
          return ParsedLocationLink(
            latitude: lat,
            longitude: lon,
            label: _extractPlaceLabelFromUri(uri),
            rawInput: rawOut,
          );
        }
      }

      // 5. OpenStreetMap hash #map=zoom/lat/lon
      final osmHash = _osmHashRegex.firstMatch(targetStr);
      if (osmHash != null) {
        final lat = double.tryParse(osmHash.group(1)!);
        final lon = double.tryParse(osmHash.group(2)!);
        if (_validPair(lat, lon)) {
          return ParsedLocationLink(
            latitude: lat,
            longitude: lon,
            label: _extractPlaceLabelFromUri(uri),
            rawInput: rawOut,
          );
        }
      }

      // 6. Repli : requête textuelle sans coordonnées (?q=Place+de+la+Nation)
      final textQuery = _cleanLabel(qp['q'] ?? qp['query']);
      if (textQuery != null && textQuery.isNotEmpty) {
        return ParsedLocationLink(
          searchQuery: textQuery,
          label: textQuery,
          rawInput: rawOut,
        );
      }
    }

    // 7. Texte libre avec coordonnées brutes ("12.3685, -1.5271")
    final rawPair = _extractCoordPair(trimmed);
    if (rawPair != null) {
      final cleanedLabel = trimmed
          .replaceAll(_coordPairRegex, '')
          .replaceAll(RegExp(r'[:\-|]+'), ' ')
          .trim();
      return ParsedLocationLink(
        latitude: rawPair.$1,
        longitude: rawPair.$2,
        label: cleanedLabel.isNotEmpty ? cleanedLabel : null,
        rawInput: rawOut,
      );
    }

    return null;
  }

  static ParsedLocationLink? _parseGeoUri(String geoUri, String rawOut) {
    final withoutScheme = geoUri.substring(4);
    final qIdx = withoutScheme.indexOf('?');
    final coordsPart = qIdx >= 0
        ? withoutScheme.substring(0, qIdx)
        : withoutScheme;
    final queryPart = qIdx >= 0 ? withoutScheme.substring(qIdx + 1) : '';

    final basePair = _extractCoordPair(coordsPart);
    final qp = queryPart.isNotEmpty
        ? Uri.splitQueryString(queryPart)
        : <String, String>{};
    final qVal = qp['q'] ?? '';
    final qPair = qVal.isNotEmpty ? _extractCoordPair(qVal) : null;

    final pair = (qPair != null && _validPair(qPair.$1, qPair.$2))
        ? qPair
        : (basePair != null && _validPair(basePair.$1, basePair.$2)
              ? basePair
              : null);

    final parenMatch = _parenLabelRegex.firstMatch(qVal);
    final label = parenMatch != null
        ? _cleanLabel(_safeDecode(parenMatch.group(1)!))
        : (qPair == null && qVal.isNotEmpty ? _cleanLabel(qVal) : null);

    if (pair != null) {
      return ParsedLocationLink(
        latitude: pair.$1,
        longitude: pair.$2,
        label: label,
        rawInput: rawOut,
      );
    }

    if (label != null && label.isNotEmpty) {
      return ParsedLocationLink(
        searchQuery: label,
        label: label,
        rawInput: rawOut,
      );
    }
    return null;
  }

  static (double, double)? _extractCoordPair(String s) {
    final m = _coordPairRegex.firstMatch(s);
    if (m == null) return null;
    final lat = double.tryParse(m.group(1)!);
    final lon = double.tryParse(m.group(2)!);
    if (_validPair(lat, lon)) {
      return (lat!, lon!);
    }
    return null;
  }

  static bool _validPair(double? lat, double? lon) {
    if (lat == null || lon == null || !lat.isFinite || !lon.isFinite) {
      return false;
    }
    if (lat == 0.0 && lon == 0.0) return false;
    return lat >= -90.0 && lat <= 90.0 && lon >= -180.0 && lon <= 180.0;
  }

  static String? _extractPlaceLabelFromUri(Uri uri) {
    final segs = uri.pathSegments;
    final placeIdx = segs.indexOf('place');
    if (placeIdx >= 0 && placeIdx + 1 < segs.length) {
      return _cleanLabel(
        _safeDecode(segs[placeIdx + 1].replaceAll('+', ' ')),
      );
    }
    return null;
  }

  static String _safeDecode(String raw) {
    try {
      return Uri.decodeComponent(raw);
    } catch (_) {
      return raw;
    }
  }

  static String? _cleanLabel(String? raw) {
    if (raw == null) return null;
    final cleaned = raw.replaceAll('+', ' ').trim();
    if (cleaned.isEmpty ||
        _coordPairRegex.hasMatch(cleaned) && cleaned.length < 30) {
      return null;
    }
    return cleaned;
  }
}

/// Service natif écoutant les liens/partages de localisation entrants sur Android/iOS.
class LocationIntentService {
  static const MethodChannel _methodChannel = MethodChannel(
    'bf.faso.nav/location_intent',
  );
  static const EventChannel _eventChannel = EventChannel(
    'bf.faso.nav/location_intent_events',
  );

  final StreamController<ParsedLocationLink> _controller =
      StreamController<ParsedLocationLink>.broadcast();
  StreamSubscription<dynamic>? _eventSub;
  bool _initialized = false;

  Stream<ParsedLocationLink> get stream => _controller.stream;

  Future<void> start() async {
    if (_initialized) return;
    _initialized = true;

    _eventSub = _eventChannel.receiveBroadcastStream().listen(
      (event) {
        if (event is String && event.isNotEmpty) {
          _handleRawPayload(event);
        }
      },
      onError: (Object err) {
        AppLogger.d('Flux intention localisation inactif: $err');
      },
    );

    try {
      final initial = await _methodChannel.invokeMethod<String>(
        'getInitialLocationLink',
      );
      if (initial != null && initial.isNotEmpty) {
        await _handleRawPayload(initial);
      }
    } catch (e) {
      AppLogger.d('Lecture lien initial ignorée: $e');
    }
  }

  Future<void> _handleRawPayload(String raw) async {
    final parsed = await LocationLinkParser.resolveAndParse(raw);
    if (parsed != null && !_controller.isClosed) {
      _controller.add(parsed);
    }
  }

  void dispose() {
    _eventSub?.cancel();
    _controller.close();
  }
}
