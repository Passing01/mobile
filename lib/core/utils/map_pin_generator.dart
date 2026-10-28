import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Générateur d'icônes bitmap personnalisées (pins de carte)
/// pour MapLibre GL avec symbole de catégorie intégré et ombre portée
class MapPinGenerator {
  static final Map<String, Uint8List> _cache = {};

  /// Retourne un dictionnaire des images de pins pré-générées pour chaque catégorie
  static Future<Map<String, Uint8List>> generateAllPins() async {
    final pins = <String, Uint8List>{};

    final configs = <String, ({Color color, IconData icon})>{
      'pin-pharmacie': (
        color: const Color(0xFF00A651),
        icon: Icons.local_pharmacy_rounded,
      ),
      'pin-station-service': (
        color: const Color(0xFFF59E0B),
        icon: Icons.local_gas_station_rounded,
      ),
      'pin-maquis-restaurant': (
        color: const Color(0xFFF97316),
        icon: Icons.restaurant_rounded,
      ),
      'pin-hopital-sante': (
        color: const Color(0xFFDC2626),
        icon: Icons.local_hospital_rounded,
      ),
      'pin-banque-distributeur': (
        color: const Color(0xFF10B981),
        icon: Icons.account_balance_rounded,
      ),
      'pin-administration': (
        color: const Color(0xFF3B82F6),
        icon: Icons.location_city_rounded,
      ),
      'pin-ecole-universite': (
        color: const Color(0xFF8B5CF6),
        icon: Icons.school_rounded,
      ),
      'pin-marche-commerce': (
        color: const Color(0xFFEC4899),
        icon: Icons.shopping_basket_rounded,
      ),
      'pin-default': (
        color: const Color(0xFF2563EB),
        icon: Icons.place_rounded,
      ),
    };

    for (final entry in configs.entries) {
      if (_cache.containsKey(entry.key)) {
        pins[entry.key] = _cache[entry.key]!;
      } else {
        final bytes = await createPinBitmap(
          color: entry.value.color,
          icon: entry.value.icon,
        );
        _cache[entry.key] = bytes;
        pins[entry.key] = bytes;
      }
    }

    final modeConfigs = <String, ({Color color, IconData icon})>{
      'mode-moto': (
        color: const Color(0xFF0F766E),
        icon: Icons.two_wheeler_rounded,
      ),
      'mode-voiture': (
        color: const Color(0xFF1D4ED8),
        icon: Icons.directions_car_rounded,
      ),
      'mode-pied': (
        color: const Color(0xFFEA580C),
        icon: Icons.directions_walk_rounded,
      ),
      'mode-velo': (
        color: const Color(0xFF16A34A),
        icon: Icons.pedal_bike_rounded,
      ),
    };

    for (final entry in modeConfigs.entries) {
      if (_cache.containsKey(entry.key)) {
        pins[entry.key] = _cache[entry.key]!;
      } else {
        final bytes = await createModeAvatarBitmap(
          color: entry.value.color,
          icon: entry.value.icon,
        );
        _cache[entry.key] = bytes;
        pins[entry.key] = bytes;
      }
    }

    return pins;
  }

  /// Dessine un pin-avatar bien visible pour représenter le mode de transport de l'utilisateur
  /// (Moto, Voiture, Piéton, Vélo) au-dessus du point GPS (iconAnchor: 'bottom').
  static Future<Uint8List> createModeAvatarBitmap({
    required Color color,
    required IconData icon,
    double size = 128.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    final centerX = size / 2;
    final tipY = size * 0.94;
    final headRadius = size * 0.36;
    final headCenterY = size * 0.42;

    // 1. Ombre portée sous la pointe et sous le médaillon
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.32)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5.0);
    canvas.drawCircle(
      Offset(centerX, headCenterY + 3),
      headRadius,
      shadowPaint,
    );

    // 2. Pointe triangulaire reliant le médaillon au point GPS exact
    final pointerPath = Path()
      ..moveTo(centerX - headRadius * 0.42, headCenterY + headRadius * 0.72)
      ..lineTo(centerX, tipY)
      ..lineTo(centerX + headRadius * 0.42, headCenterY + headRadius * 0.72)
      ..close();

    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    final borderPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5.0
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(pointerPath, fillPaint);
    canvas.drawPath(pointerPath, borderPaint);

    // 3. Disque principal coloré du mode (Moto, Voiture, Vélo, Piéton)
    canvas.drawCircle(Offset(centerX, headCenterY), headRadius, fillPaint);
    canvas.drawCircle(Offset(centerX, headCenterY), headRadius, borderPaint);

    // 4. Petit point blanc à la pointe inférieure
    canvas.drawCircle(
      Offset(centerX, tipY - 2),
      3.5,
      Paint()..color = Colors.white,
    );

    // 5. Pictogramme blanc grand format (marcheur, moto, voiture, vélo)
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: headRadius * 1.28,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: Colors.white,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        centerX - textPainter.width / 2,
        headCenterY - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Dessine un pin de carte avec pointe vers le bas, ombre et pictogramme
  static Future<Uint8List> createPinBitmap({
    required Color color,
    required IconData icon,
    double size = 96.0,
  }) async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Rect.fromLTWH(0, 0, size, size));

    final pinWidth = size * 0.62;
    final pinHeight = size * 0.82;
    final centerX = size / 2;
    final tipY = size * 0.94;
    final headRadius = pinWidth / 2;
    final headCenterY = tipY - pinHeight + headRadius;

    // 1. Ombre au sol (ellipse douce sous la pointe)
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.28)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 3.5);
    canvas.drawOval(
      Rect.fromCenter(
        center: Offset(centerX, tipY + 2),
        width: pinWidth * 0.45,
        height: 6.0,
      ),
      shadowPaint,
    );

    // 2. Tracé vectoriel du pin (goutte inversée / teardrop)
    final path = Path();
    path.moveTo(centerX, tipY);
    // Courbe flanc gauche
    path.cubicTo(
      centerX - pinWidth * 0.52,
      tipY - pinHeight * 0.42,
      centerX - pinWidth * 0.5,
      headCenterY,
      centerX - pinWidth * 0.5,
      headCenterY,
    );
    // Dôme supérieur
    path.arcTo(
      Rect.fromCircle(center: Offset(centerX, headCenterY), radius: headRadius),
      3.14159265,
      3.14159265,
      false,
    );
    // Courbe flanc droit
    path.cubicTo(
      centerX + pinWidth * 0.5,
      headCenterY,
      centerX + pinWidth * 0.52,
      tipY - pinHeight * 0.42,
      centerX,
      tipY,
    );
    path.close();

    // 3. Remplissage avec la couleur de catégorie
    final fillPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;
    canvas.drawPath(path, fillPaint);

    // 4. Contour blanc extérieur pour contraste optimal sur n'importe quel fond
    final strokePaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5;
    canvas.drawPath(path, strokePaint);

    // 5. Disque intérieur blanc au centre de la tête
    final innerDiscRadius = headRadius * 0.62;
    final discPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(Offset(centerX, headCenterY), innerDiscRadius, discPaint);

    // 6. Dessin du pictogramme vectoriel au centre
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    textPainter.text = TextSpan(
      text: String.fromCharCode(icon.codePoint),
      style: TextStyle(
        fontSize: innerDiscRadius * 1.35,
        fontFamily: icon.fontFamily,
        package: icon.fontPackage,
        color: color,
        fontWeight: FontWeight.bold,
      ),
    );
    textPainter.layout();
    textPainter.paint(
      canvas,
      Offset(
        centerX - textPainter.width / 2,
        headCenterY - textPainter.height / 2,
      ),
    );

    final picture = recorder.endRecording();
    final img = await picture.toImage(size.toInt(), size.toInt());
    final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }
}
